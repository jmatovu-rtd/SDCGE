# Recursive-dynamic LINKAGE solver.
#
# Each period is solved as a STATIC equilibrium using the cleaned static model.
# Between periods we update the exogenous state (capital stock, labor supply,
# productivity, etc.) using the solved period-t values, then re-build and re-
# solve for period t+1.
#
# Typical usage:
#
#     data, history = run_recursive_dynamic!(periods=10)
#
# Or specify growth/depreciation rates:
#
#     data, history = run_recursive_dynamic!(
#         periods=10,
#         delta=0.05,            # capital depreciation rate
#         g_labor=0.02,          # labor force growth
#         g_tfp=0.015,           # total factor productivity growth
#         g_land=0.0,            # land supply growth
#         outdir="results/dynamic")
#
# Outputs:
# - results/dynamic/period_<t>/...   (full static-model outputs per period)
# - results/dynamic/time_series.csv  (key macro indicators stacked across t)

"""
Update exogenous data fields (PAR + supplies) using period-t solution.
This is the recursive-dynamic update step:

* Capital:    K[t+1] = (1−δ)·K[t] + I[t]   where I[t] = FDInv (investment quantity)
* Labor:      LS[t+1] = (1+g_labor)·LS[t]
* TFP:        AT[t+1] = (1+g_tfp)·AT[t]
* Land/NR:    grow at g_land / g_nres (default 0)

Returns the modified `data`.
"""
function update_period_data!(data::LinkageData, m;
        delta::Float64=0.05,
        g_labor::Float64=0.02,
        g_tfp::Float64=0.0,
        g_land::Float64=0.0,
        g_nres::Float64=0.0)

    PAR = data.metadata[:PAR]
    S = data.sets
    i = S[:i]; l = S[:l]; v = S[:v]; gz = S[:gz]; ag = S[:ag]; h = S[:h]

    # ── 1. CAPITAL ACCUMULATION (vintage update) ─────────────────────────────
    # Proper recursive-dynamic capital flow:
    #   K_total[t]   = K_Old[t] + K_New[t]                  (capital at start of t)
    #   K_Old[t+1]   = (1 − δ) · K_total[t]                 (surviving capital)
    #   K_New[t+1]   = sector_share · FDInv_t               (this period's investment)
    # =>K_total[t+1] = (1 − δ) · K_total[t] + FDInv_t       (standard Solow update)
    fdinv = try JuMP.value(m[:FDInv]) catch; missing end
    if fdinv isa Real && isfinite(fdinv)
        # Sector shares from current total capital (used to allocate investment).
        sector_K = Dict{Any,Float64}(ii =>
            sum(get(PAR[:KSupply], (ii,vv), 0.0) for vv in v) for ii in i)
        total_K = sum(values(sector_K))
        for ii in i
            share = total_K > 1.0e-9 ? sector_K[ii] / total_K : 1.0 / length(i)
            # All surviving capital becomes "Old" next period.
            PAR[:KSupply][(ii,"Old")] = max((1 - delta) * sector_K[ii], 1.0e-9)
            # New capital from this period's investment (sectoral share of FDInv).
            PAR[:KSupply][(ii,"New")] = max(share * fdinv,             1.0e-9)
            # K0 (static-period anchor in F_K0/F_30) equals KSupply[(i,"Old")].
            PAR[:K0][ii] = PAR[:KSupply][(ii,"Old")]
        end
    end

    # ── 2. LABOR SUPPLY GROWTH ───────────────────────────────────────────────
    for ll in l
        PAR[:LSupply][ll] *= (1 + g_labor)
        for gg in gz
            PAR[:LS0][(ll, gg)] *= (1 + g_labor)
        end
        PAR[:LY0][ll] *= (1 + g_labor)
    end

    # ── 3. TOTAL FACTOR PRODUCTIVITY ─────────────────────────────────────────
    if abs(g_tfp) > 1.0e-12
        for ii in i
            PAR[:AT][ii] *= (1 + g_tfp)
        end
    end

    # ── 4. LAND AND NATURAL-RESOURCE SUPPLIES ────────────────────────────────
    if abs(g_land) > 1.0e-12
        for ii in i
            PAR[:TSupply][ii] *= (1 + g_land)
        end
        PAR[:TY0] *= (1 + g_land)
        if haskey(PAR[:chi_T], :land)
            PAR[:chi_T][:land] *= (1 + g_land)
        end
        # Re-normalize gamma_T to preserve sum to 1
        tot_t = sum(get(PAR[:TSupply], ii, 0.0) for ii in ag)
        if tot_t > 1.0e-9
            for ii in i
                PAR[:gamma_T][ii] = (ii in ag) ? PAR[:TSupply][ii] / tot_t : 0.0
            end
        end
    end
    if abs(g_nres) > 1.0e-12
        for ii in i
            PAR[:FSupply][ii] *= (1 + g_nres)
            PAR[:chi_F][ii] *= (1 + g_nres)
        end
        PAR[:FY0] *= (1 + g_nres)
    end

    # ── 5. UPDATE AGGREGATE ANCHORS USED BY INITIALIZATION ────────────────────
    PAR[:KY0] = sum(get(PAR[:KSupply], (ii,vv), 0.0) for ii in i for vv in v)
    # YH benchmark: factor incomes (assuming PF/W/R = 1 at next benchmark).
    PAR[:YH0] = Dict(hh => max(
        PAR[:TY0] + PAR[:FY0] + sum(values(PAR[:LY0])) + PAR[:KY0], 1.0e-9)
        for hh in h)

    # Re-normalize gamma_K to preserve sum to 1
    tot_k_old = sum(get(PAR[:KSupply], (ii,"Old"), 0.0) for ii in i)
    if tot_k_old > 1.0e-9
        for ii in i
            PAR[:gamma_K][ii] = PAR[:KSupply][(ii,"Old")] / tot_k_old
        end
    end

    return data
end

"""
Extract a compact named-tuple of key macro indicators for one period.
"""
function _period_summary(m, data::LinkageData, period::Int)
    S = data.sets
    function _v(sym, idx=())
        haskey(m, sym) || return missing
        try
            return isempty(idx) ? JuMP.value(m[sym]) : JuMP.value(m[sym][idx...])
        catch
            return missing
        end
    end
    function _sum(sym, keys)
        haskey(m, sym) || return missing
        total = 0.0
        try
            for k in keys
                v = JuMP.value(m[sym][k...])
                v isa Real && (total += float(v))
            end
            return total
        catch
            return missing
        end
    end

    return (
        period         = period,
        GDP_R1         = _v(:GDP, ("R1",)),
        RGDP_R1        = _v(:RGDP, ("R1",)),
        PGDP_R1        = _v(:PGDP, ("R1",)),
        CPI_R1         = _v(:CPI, ("R1",)),
        XP_total       = _sum(:XP, [(ii,) for ii in S[:i]]),
        YH_HH          = _v(:YH, ("HH",)),
        YC_HH          = _v(:YC, ("HH",)),
        SAV_HH         = _v(:SAV, ("HH",)),
        GOVREV         = _v(:YG),
        GEXP           = (_v(:PFD, ("Gov",)) isa Real && _v(:FD, ("Gov",)) isa Real) ?
                          _v(:PFD, ("Gov",)) * _v(:FD, ("Gov",)) : missing,
        INVEST         = (_v(:PFD, ("Inv",)) isa Real && _v(:FD, ("Inv",)) isa Real) ?
                          _v(:PFD, ("Inv",)) * _v(:FD, ("Inv",)) : missing,
        FDInv          = _v(:FDInv),
        Sg             = _v(:Sg),
        InvSh          = _v(:InvSh),
        KS             = _v(:KS),
        KActual        = _v(:KActual),
        TR             = _v(:TR),
        TLnd           = _v(:TLnd),
        PTLnd          = _v(:PTLnd),
        PNUM           = _v(:PNUM),
        TY             = _v(:TY),
        FY             = _v(:FY),
        KY             = _v(:KY),
        LY_UnSkLab     = _v(:LY, ("UnSkLab",)),
        LY_SkLab       = _v(:LY, ("SkLab",)),
    )
end

"""
Write the per-period summaries as a single time-series CSV (one row per period).
"""
function _write_time_series(history::Vector, outdir::AbstractString)
    isempty(history) && return nothing
    cols = collect(keys(history[1]))
    path = joinpath(outdir, "time_series.csv")
    mkpath(outdir)
    open(path, "w") do io
        println(io, join(string.(cols), ","))
        for row in history
            println(io, join((string(getfield(row, c)) for c in cols), ","))
        end
    end
    return path
end

"""
Collect ALL variable values for one solved period into a flat dict
`(variable_symbol, index_tuple) => value`. Used to build the consolidated
Excel workbook in `_write_dynamic_xlsx`.

For JuMP `DenseAxisArray`s (the common case), `eachindex` returns
`CartesianIndex` values that don't preserve the original axis labels (e.g.
"R1", "P001"). We translate to axis labels via `obj.axes` so the workbook
shows the readable sector / region / vintage names.
"""
function _collect_period_values(m)
    snap = Dict{Tuple{Symbol,Any},Float64}()
    for (name, obj) in object_dictionary(m)
        if obj isa JuMP.VariableRef
            try
                v = JuMP.value(obj)
                v isa Real && (snap[(name, ())] = float(v))
            catch
            end
            continue
        end
        # Try to get axis labels for DenseAxisArray; fall back to raw index.
        labelfn = if hasproperty(obj, :axes)
            ax = obj.axes
            (idx) -> begin
                if idx isa CartesianIndex
                    Tuple(ax[d][idx[d]] for d in 1:length(idx))
                elseif idx isa Tuple
                    Tuple(ax[d][idx[d]] for d in 1:length(idx))
                else
                    (ax[1][idx],)
                end
            end
        else
            (idx) -> idx
        end
        try
            for idx in eachindex(obj)
                var = obj[idx]
                var isa JuMP.VariableRef || continue
                try
                    v = JuMP.value(var)
                    v isa Real || continue
                    lbl = try labelfn(idx) catch; idx end
                    snap[(name, lbl)] = float(v)
                catch
                end
            end
        catch
        end
    end
    return snap
end

"""
Write the consolidated dynamic workbook with one sheet per variable family.

Sheet layout (per variable):
- Row 1: ["index", "period_1", "period_2", ..., "period_T"]
- Subsequent rows: [index_label, value_t1, value_t2, ..., value_tT]

Plus two summary sheets:
- "macro_summary": named indicators from `history`
- "scalars": all scalar variables (no index) tracked across periods
"""
function _write_dynamic_xlsx(snapshots::Vector, history::Vector, outdir::AbstractString)
    isempty(snapshots) && return nothing
    mkpath(outdir)
    path = joinpath(outdir, "dynamic_results.xlsx")
    T = length(snapshots)

    # Discover all variable names across all snapshots.
    var_indices = Dict{Symbol, Set{Any}}()
    for snap in snapshots
        for ((name, idx), _) in snap
            push!(get!(var_indices, name, Set{Any}()), idx)
        end
    end

    period_cols = ["period_$(t)" for t in 1:T]

    XLSX.openxlsx(path, mode="w") do xf
        # ── Sheet: macro_summary ──────────────────────────────────────────────
        if !isempty(history)
            cols = collect(keys(history[1]))
            sheet_name = "macro_summary"
            sheet = if XLSX.sheetnames(xf)[1] == "Sheet1"
                XLSX.rename!(xf[1], sheet_name); xf[1]
            else
                XLSX.addsheet!(xf, sheet_name)
            end
            # Header row: ["indicator", "period_1", ..., "period_T"]
            sheet["A1"] = "indicator"
            for t in 1:T
                sheet[XLSX.CellRef(1, t+1)] = "period_$(t)"
            end
            for (i, ind) in enumerate(cols)
                sheet[XLSX.CellRef(i+1, 1)] = string(ind)
                for t in 1:T
                    v = getfield(history[t], ind)
                    if v isa Real && isfinite(v)
                        sheet[XLSX.CellRef(i+1, t+1)] = float(v)
                    end
                end
            end
        end

        # ── One sheet per variable ────────────────────────────────────────────
        # Sort variable names so sheet ordering is deterministic.
        for vname in sort(collect(keys(var_indices)); by=string)
            sheet_name = string(vname)
            # Excel sheet names max 31 chars; truncate if needed.
            length(sheet_name) > 31 && (sheet_name = sheet_name[1:31])
            sheet = XLSX.addsheet!(xf, sheet_name)

            indices = sort(collect(var_indices[vname]); by=_index_sort_key)

            # Header row.
            sheet["A1"] = "index"
            for t in 1:T
                sheet[XLSX.CellRef(1, t+1)] = "period_$(t)"
            end

            # Data rows.
            for (i, idx) in enumerate(indices)
                sheet[XLSX.CellRef(i+1, 1)] = _index_label(idx)
                for t in 1:T
                    v = get(snapshots[t], (vname, idx), nothing)
                    if v isa Real && isfinite(v)
                        sheet[XLSX.CellRef(i+1, t+1)] = float(v)
                    end
                end
            end
        end
    end
    return path
end

_index_label(idx) = idx isa Tuple ? join(string.(idx), "|") : (idx === () ? "" : string(idx))
_index_sort_key(idx) = idx isa Tuple ? join(string.(idx), "|") : string(idx)

"""
    run_recursive_dynamic!(; periods=10, delta=0.05, g_labor=0.02, g_tfp=0.015,
                           g_land=0.0, g_nres=0.0,
                           outdir="results/dynamic", show_solver_output=false)

Solve the LINKAGE model recursively over `periods` periods. Each period is a
static-equilibrium solve with capital, labor and productivity updated between
periods from the previous solution.

Returns `(data, history)` where `history` is a vector of named tuples — one per
period — containing key macro indicators. The full per-period CSVs are written
to `outdir/period_<t>/`, and a consolidated `time_series.csv` is written to
`outdir/`.
"""
function run_recursive_dynamic!(;
        periods::Int=10,
        delta::Float64=0.05,
        g_labor::Float64=0.02,
        g_tfp::Float64=0.015,
        g_land::Float64=0.0,
        g_nres::Float64=0.0,
        outdir::AbstractString="results/dynamic",
        show_solver_output::Bool=false)

    mkpath(outdir)
    data = init_data()
    prepare_data!(data)

    history    = Vector{NamedTuple}()
    snapshots  = Vector{Dict{Tuple{Symbol,Any},Float64}}()

    for t in 1:periods
        println("\n========================================")
        println("  Recursive-Dynamic Period t = $t / $periods")
        println("========================================")

        m = model(data; show_solver_output=show_solver_output)
        solve_model!(m; show_diagnostics=false)

        # Capture per-period values for the consolidated workbook.
        push!(snapshots, _collect_period_values(m))
        push!(history,   _period_summary(m, data, t))

        # Update exogenous state for next period (skip after the last period).
        if t < periods
            update_period_data!(data, m;
                delta=delta, g_labor=g_labor, g_tfp=g_tfp,
                g_land=g_land, g_nres=g_nres)
        end
    end

    # ── Consolidated outputs ──────────────────────────────────────────────────
    # One Excel workbook: one sheet per variable family, columns = periods.
    xlsx_path = _write_dynamic_xlsx(snapshots, history, outdir)
    println("\nDynamic results written to ", xlsx_path)

    # Time-series CSV summary (handy for quick inspection / downstream tools).
    _write_time_series(history, outdir)
    println("Time-series summary written to ", joinpath(outdir, "time_series.csv"))

    return data, history, snapshots
end
