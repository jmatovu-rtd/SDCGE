# Plotting utilities for LCGE/LINKAGE results.
# jl is now a direct dependency (added to Project.toml) so we can load it
# at module include time. This avoids the world-age issue that arises when the
# package is loaded lazily inside a function.

using Plots

function _lcge_parse_results_csv(path::AbstractString)
    lines = readlines(path)
    isempty(lines) && return NamedTuple[]
    header = split(lines[1], ",")
    rows = NamedTuple[]
    for line in lines[2:end]
        cols = split(line, ",")
        length(cols) < length(header) && continue
        nt = (; Dict(Symbol(header[i]) => cols[i] for i in eachindex(header))...)
        push!(rows, nt)
    end
    return rows
end

function _lcge_try_float(x)
    try
        return parse(Float64, string(x))
    catch
        return NaN
    end
end

function _lcge_plot_variable(results_dir::AbstractString, variable_name::AbstractString, outdir::AbstractString)
path = joinpath(results_dir, "results_$(variable_name).csv")
    if !isfile(path)
        return nothing
    end

    rows = _lcge_parse_results_csv(path)
    isempty(rows) && return nothing

    labels = [string(r.index) for r in rows]
    values = [_lcge_try_float(r.value) for r in rows]

    keep = .!isnan.(values)
    labels = labels[keep]
    values = values[keep]

    isempty(values) && return nothing

    # Keep plots readable for large models.
    max_items = min(length(values), 30)
    labels = labels[1:max_items]
    values = values[1:max_items]

    plt = bar(
        labels,
        values;
        legend=false,
        title="$(variable_name) results",
        xlabel="Index",
        ylabel="Value",
        xrotation=45,
        size=(1000, 600),
    )

    mkpath(outdir)
    outfile = joinpath(outdir, "plot_$(variable_name).png")
    savefig(plt, outfile)
    return outfile
end

"""Create PNG plots from exported result files.

By default this plots key variables if their CSV files exist:
`XP`, `GDP`, `RGDP`, `CPI`, `XM`, `E`, `YH`, and `SAV`.
"""
function plot_results(results_dir::AbstractString="results"; outdir::AbstractString=joinpath(results_dir, "plots"), variables=["XP", "GDP", "RGDP", "CPI", "XM", "E", "YH", "SAV"])
    mkpath(outdir)
    files = String[]
    for vname in variables
        f = _lcge_plot_variable(results_dir, string(vname), outdir)
        if f !== nothing
            push!(files, f)
        end
    end
    return files
end

"""Convenience function: export CSV results and create plots."""
function export_results_and_plots!(m, data::LinkageData; results_dir::AbstractString="results", plots_dir::AbstractString=joinpath(results_dir, "plots"))
    export_results!(m, data; outdir=results_dir)
    return plot_results(results_dir; outdir=plots_dir)
end

# ──────────────────────────────────────────────────────────────────────────────
# Dynamic (multi-period) plotting from the consolidated XLSX workbook.
# ──────────────────────────────────────────────────────────────────────────────

"""
    plot_dynamic_results(xlsx_path::AbstractString="results/dynamic/dynamic_results.xlsx";
                        outdir = "results/dynamic/plots",
                        variables = nothing,
                        max_lines = 12)

Read the consolidated dynamic workbook and create one PNG plot per variable
sheet showing the time trajectory across periods.

* `variables = nothing` → plot every sheet (except `macro_summary`).
* `variables = [...]`   → only the listed sheet names.
* For multi-index variables (XP[P001], XP[P002], ...), at most `max_lines`
  indices are plotted (the largest by period-1 value), with the remainder
  aggregated into a "..others (sum)" line.

Returns the list of PNG file paths written.
"""
function plot_dynamic_results(xlsx_path::AbstractString="results/dynamic/dynamic_results.xlsx";
        outdir::AbstractString=joinpath(dirname(xlsx_path), "plots"),
        variables::Union{Nothing,Vector{<:AbstractString}}=nothing,
        max_lines::Int=12)

    isfile(xlsx_path) || error("plot_dynamic_results: file not found: $xlsx_path")
mkpath(outdir)
    files = String[]

    XLSX.openxlsx(xlsx_path, mode="r") do xf
        sheet_names = XLSX.sheetnames(xf)
        targets = variables === nothing ?
            [s for s in sheet_names if s != "macro_summary"] :
            [string(s) for s in variables if s in sheet_names]

        # ── macro_summary: one panel of key indicators ────────────────────────
        if "macro_summary" in sheet_names && (variables === nothing || "macro_summary" in string.(variables))
            f = _plot_macro_summary(xf["macro_summary"], outdir)
            f !== nothing && push!(files, f)
        end

        for vname in targets
            f = _plot_variable_sheet(xf[vname], vname, outdir; max_lines=max_lines)
            f !== nothing && push!(files, f)
        end
    end
    return files
end

"""Read an XLSX sheet into (header::Vector, index::Vector{String}, data::Matrix{Float64})."""
function _read_sheet_matrix(sheet)
    data = sheet[:]
    isempty(data) && return (String[], String[], Matrix{Float64}(undef, 0, 0))
    nrows, ncols = size(data)
    header = [string(something(data[1, j], "")) for j in 1:ncols]
    indices = String[]
    rows = Vector{Vector{Float64}}()
    for r in 2:nrows
        push!(indices, string(something(data[r, 1], "")))
        rowvals = Float64[]
        for c in 2:ncols
            x = data[r, c]
            push!(rowvals, x isa Real ? float(x) : NaN)
        end
        push!(rows, rowvals)
    end
    nperiods = ncols - 1
    mat = nperiods > 0 ? reduce(hcat, rows)' : Matrix{Float64}(undef, 0, 0)
    return (header[2:end], indices, Matrix{Float64}(mat))
end

function _plot_macro_summary(sheet, outdir)
    period_cols, indicators, mat = _read_sheet_matrix(sheet)
    isempty(indicators) && return nothing
    periods = 1:length(period_cols)

    # Pick a handful of headline indicators if available.
    headline = ["GDP_R1", "RGDP_R1", "YH_HH", "INVEST", "KS", "GOVREV"]
    picks = [i for (i, lbl) in enumerate(indicators) if lbl in headline]
    isempty(picks) && (picks = collect(1:min(6, length(indicators))))

    plt = plot(; title="Dynamic macro indicators", xlabel="Period",
                     ylabel="Value", legend=:outerright, size=(1100, 650))
    for i in picks
        ys = mat[i, :]
        any(isfinite, ys) || continue
        plot!(plt, collect(periods), ys; label=indicators[i], lw=2,
                    marker=:circle, markersize=4)
    end
    outfile = joinpath(outdir, "plot_macro_summary.png")
    savefig(plt, outfile)
    return outfile
end

# ──────────────────────────────────────────────────────────────────────────────
# Cross-scenario plotting from the consolidated all_scenarios_results.xlsx.
# ──────────────────────────────────────────────────────────────────────────────

"""
    plot_all_scenarios(xlsx_path; outdir="plots", indicators=nothing,
                       max_index_per_var=6)

Read the consolidated multi-scenario workbook (sheets are scenario × index
rows × period columns) and create comparison plots:

* `plot_macro_summary.png`  — one panel per key indicator, one line per scenario.
* `plot_<var>__<index>.png` — for each chosen variable, one PNG per index
  showing all scenarios as different-colored lines. To keep the file count
  manageable, only `max_index_per_var` indices are plotted per variable
  (the largest by period-1 baseline value).

Returns a vector of generated file paths.
"""
function plot_all_scenarios(xlsx_path::AbstractString;
        outdir::AbstractString=joinpath(dirname(xlsx_path), "plots"),
        indicators::Union{Nothing,Vector{<:AbstractString}}=nothing,
        max_index_per_var::Int=6,
        variables::Union{Nothing,Vector{<:AbstractString}}=nothing)

    isfile(xlsx_path) || error("plot_all_scenarios: file not found: $xlsx_path")
    mkpath(outdir)
    files = String[]

    XLSX.openxlsx(xlsx_path, mode="r") do xf
        names = XLSX.sheetnames(xf)
        # ── macro_summary ────────────────────────────────────────────────────
        if "macro_summary" in names
            f = _plot_scenarios_macro(xf["macro_summary"], outdir; indicators=indicators)
            f !== nothing && push!(files, f)
        end
        # ── one PNG per (variable, index) ────────────────────────────────────
        targets = variables === nothing ?
            [s for s in names if !(s in ("scenarios", "macro_summary"))] :
            [string(v) for v in variables if v in names]
        for vname in targets
            for f in _plot_scenarios_variable(xf[vname], vname, outdir; max_index=max_index_per_var)
                push!(files, f)
            end
        end
    end
    return files
end

function _scenario_var_table(sheet)
    data = sheet[:]
    isempty(data) && return (String[], String[], Float64[], Matrix{Float64}(undef, 0, 0))
    nrows, ncols = size(data)
    period_cols = [string(something(data[1, j], "")) for j in 3:ncols]
    scen_col  = String[]
    index_col = String[]
    rows      = Vector{Vector{Float64}}()
    for r in 2:nrows
        push!(scen_col,  string(something(data[r, 1], "")))
        push!(index_col, string(something(data[r, 2], "")))
        push!(rows,      [data[r, c] isa Real ? float(data[r, c]) : NaN for c in 3:ncols])
    end
    mat = isempty(rows) ? Matrix{Float64}(undef, 0, 0) : Matrix{Float64}(reduce(hcat, rows)')
    return (period_cols, scen_col, index_col, mat)
end

function _plot_scenarios_macro(sheet, outdir; indicators=nothing)
    period_cols, scens, inds, mat = _scenario_var_table(sheet)
    isempty(scens) && return nothing
    T = length(period_cols)
    headline = indicators === nothing ?
        ["GDP_R1", "RGDP_R1", "YH_HH", "INVEST", "KS", "GOVREV"] :
        [string(x) for x in indicators]
    files = String[]
    for ind in headline
        plt = plot(; title="$(ind) across scenarios", xlabel="Period",
                   ylabel=ind, legend=:outerright, size=(1100, 650))
        any_line = false
        for (i, (s, idx)) in enumerate(zip(scens, inds))
            idx == ind || continue
            ys = mat[i, :]
            any(isfinite, ys) || continue
            plot!(plt, 1:T, ys; label=s, lw=2, marker=:circle, markersize=4)
            any_line = true
        end
        any_line || continue
        outfile = joinpath(outdir, "plot_macro_$(ind).png")
        savefig(plt, outfile)
        push!(files, outfile)
    end
    isempty(files) && return nothing
    return files[1]   # return one representative file; callers iterate via plot_all_scenarios
end

function _plot_scenarios_variable(sheet, vname::AbstractString, outdir; max_index::Int=6)
    period_cols, scens, inds, mat = _scenario_var_table(sheet)
    (isempty(scens) || isempty(period_cols)) && return String[]
    T = length(period_cols)

    # Group rows by index value to identify which indices to plot.
    by_index = Dict{String, Vector{Int}}()
    for (i, idx) in enumerate(inds)
        push!(get!(by_index, idx, Int[]), i)
    end
    isempty(by_index) && return String[]

    # Sort indices by mean magnitude in period 1 across scenarios; keep top N.
    sort_keys = sort(collect(keys(by_index)); by=k -> begin
        vs = [mat[i, 1] for i in by_index[k] if i <= size(mat,1)]
        isempty(vs) ? -Inf : abs(mean(filter(isfinite, vs); init=0.0))
    end, rev=true)
    keep = sort_keys[1:min(max_index, length(sort_keys))]

    files = String[]
    for idx in keep
        plt = plot(; title="$(vname)[$(idx)] across scenarios", xlabel="Period",
                   ylabel=vname, legend=:outerright, size=(1100, 650))
        any_line = false
        for i in by_index[idx]
            ys = mat[i, :]
            any(isfinite, ys) || continue
            plot!(plt, 1:T, ys; label=scens[i], lw=1.6, marker=:circle, markersize=3)
            any_line = true
        end
        any_line || continue
        # Sanitize filename: only [A-Za-z0-9_].
        safe_idx = replace(idx, r"[^A-Za-z0-9_]" => "_")
        outfile = joinpath(outdir, "plot_$(vname)__$(safe_idx).png")
        savefig(plt, outfile)
        push!(files, outfile)
    end
    return files
end

# Lightweight mean for vector of finite floats (avoids extra Statistics dep).
function mean(v::AbstractVector{Float64}; init::Float64=0.0)
    isempty(v) && return init
    return sum(v) / length(v)
end

function _plot_variable_sheet(sheet, vname::AbstractString, outdir; max_lines::Int=12)
    period_cols, indices, mat = _read_sheet_matrix(sheet)
    (isempty(indices) || isempty(period_cols)) && return nothing
    periods = 1:length(period_cols)

    # Determine plotting layout based on number of indices.
    nidx = length(indices)
    plt = plot(; title="$(vname) over time", xlabel="Period",
                     ylabel=vname, legend=(nidx > 1 ? :outerright : :topright),
                     size=(1100, 650))

    if nidx == 1
        ys = mat[1, :]
        any(isfinite, ys) && plot!(plt, collect(periods), ys;
            label=isempty(indices[1]) ? vname : indices[1], lw=2,
            marker=:circle, markersize=5)
    else
        # Rank indices by period-1 magnitude; plot top `max_lines`.
        p1_vals = [isfinite(mat[i,1]) ? abs(mat[i,1]) : -Inf for i in 1:nidx]
        order   = sortperm(p1_vals; rev=true)
        topN    = order[1:min(max_lines, nidx)]
        rest    = order[(min(max_lines, nidx)+1):end]

        for i in topN
            ys = mat[i, :]
            any(isfinite, ys) || continue
            plot!(plt, collect(periods), ys; label=indices[i], lw=1.5,
                        marker=:circle, markersize=3)
        end
        if !isempty(rest)
            ys_other = [sum(isfinite(mat[i,t]) ? mat[i,t] : 0.0 for i in rest) for t in 1:length(periods)]
            plot!(plt, collect(periods), ys_other; label="..others (sum)",
                        lw=1.5, linestyle=:dash, marker=:square, markersize=3)
        end
    end

    outfile = joinpath(outdir, "plot_$(vname).png")
    savefig(plt, outfile)
    return outfile
end
