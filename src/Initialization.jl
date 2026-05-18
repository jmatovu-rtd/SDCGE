# Compute declaration-time start values for Variables.jl.
# Variables.jl calls initial_values_from_sam(data) before declaring JuMP variables,
# then passes these values through the `start = ...` keyword in every @variable line.

function _put_start!(starts::Dict{Tuple,Float64}, name::Symbol, value; raw::Bool=false)
    val = raw ? float(value) : max(float(value), 1.0e-9)
    starts[(name,)] = val
    return nothing
end

function _put_start!(starts::Dict{Tuple,Float64}, name::Symbol, inds::Tuple, value; raw::Bool=false)
    val = raw ? float(value) : max(float(value), 1.0e-9)
    starts[(name, inds...)] = val
    return nothing
end

function init_value(starts::Dict{Tuple,Float64}, name::Symbol, inds...)
    return get(starts, (name, inds...), get(starts, (name,), 1.0))
end

function init_value_raw(starts::Dict{Tuple,Float64}, name::Symbol, inds...)
    return get(starts, (name, inds...), get(starts, (name,), 0.0))
end

function initial_values_from_sam(data::LinkageData)
    default_sets!(data)
    S = data.sets
    i = S[:i]; j = S[:j]; k = S[:k]; r = S[:r]; rp = S[:rp]
    v = S[:v]; l = S[:l]; h = S[:h]; f = S[:f]; t = S[:t]
    gz = S[:gz]; e = S[:e]
    PAR = parameters(data)

    starts = Dict{Tuple,Float64}()

    # scalar price/macro defaults
    for nm in [:PNUM,:PABS,:PTLnd,:PFD,:WXMg,:WPMg,:WRR,:TAXREV,:MTAXREV,:RMTAXREV,
               :GOVREV,:GEXP,:SAVE,:INVEST,:TY,:FY,:KY,:TLnd,:KS,:TR,:FDInv,
               :KActual,:GammaInv,:KNorm,:TarY,:RTarY,:YG,:InvSh,:GDPMPr,:LambdaAIDADS]
        _put_start!(starts, nm, 1.0)
    end
    for nm in [:GDEF,:WALRAS,:Sg,:RSg]
        _put_start!(starts, nm, 0.0; raw=true)
    end

    # Sector-level starts from calibrated SAM benchmarks.
    for ii in i
        x0  = get(PAR[:output0], ii, 1.0)
        nd0 = get(PAR[:intermediate0], ii, 1.0)
        va0 = get(PAR[:value_added0], ii, 1.0)
        for nm in [:XP,:XA,:XD,:XQ,:XMT,:GOVDEM,:INVDEM,:XDc,:XMc,:XDd,:XDs,:XMTd,:ES,:XMgr,:AXMg,:APMg,:QINV,:OPEN,:GDPPC]
            _put_start!(starts, nm, (ii,), x0)
        end
        for nm in [:PX,:PP,:PND,:PA,:Pfeed,:PT,:PF,:PMT,:PD,:PET,:PC,:PQ,:RR,:Ts,:Fs,:KSs]
            _put_start!(starts, nm, (ii,), 1.0)
        end
        for nm in [:PROFIT,:ULD,:SLD,:fert,:feed,:Td,:Fd,:UW,:SW,:NPT,:ChiF,:EtaP]
            _put_start!(starts, nm, (ii,), 1.0)
        end
        _put_start!(starts, :ND, (ii,), nd0)
        _put_start!(starts, :XM, (ii,), max(0.05*x0, 1.0e-9))
        _put_start!(starts, :E,  (ii,), max(0.05*x0, 1.0e-9))
        _put_start!(starts, :D,  (ii,), max(0.90*x0, 1.0e-9))
        _put_start!(starts, :KF_d, (ii,), sum(get(PAR[:KSupply], (ii,vv), va0 / max(length(v),1)) for vv in v))
        for vv in v
            kval = get(PAR[:KSupply], (ii,vv), max(va0 / max(length(v),1), 1.0e-9))
            for nm in [:XPv,:VA,:UVCv,:PVA,:HKTEF,:PHKTEF,:Pfert,:HKTE,:PHKTE,:XEp,:PEp,:HKT,:PHKT,:KT,:PKT,:Kvd,:KTEL,:PKTEL,:TFD,:PTFD,:R,:NR,:KStock,:INVK,:CHIv,:K0]
                _put_start!(starts, nm, (ii,vv), nm in [:PVA,:PHKTEF,:Pfert,:PHKTE,:PEp,:PHKT,:PKT,:PKTEL,:PTFD,:R,:NR] ? 1.0 : kval)
            end
            for tt in t
                _put_start!(starts, :LambdaK, (ii,vv,tt), 1.0)
            end
        end
        for ll in l
            _put_start!(starts, :LF_d, (ll,ii), max(get(PAR[:LSupply], ll, 1.0) / max(length(i),1), 1.0e-9))
            for nm in [:LV,:W,:NW]
                _put_start!(starts, nm, (ll,ii), 1.0)
            end
            for tt in t
                _put_start!(starts, :LambdaL, (ll,ii,tt), 1.0)
            end
        end
        for tt in t
            for nm in [:LambdaT,:LambdaF,:ChiP,:AlphaP,:PhiP]
                _put_start!(starts, nm, (ii,tt), 1.0)
            end
            for ee in e
                _put_start!(starts, :LambdaEP, (ee,ii,tt), 1.0)
            end
        end
    end

    for jj in j, ii in i
        _put_start!(starts, :XAp, (jj,ii), max(get(PAR[:intermediate0], jj, 1.0) / max(length(i),1), 1.0e-9))
        for nm in [:PAp,:XDp,:XMp,:VDFM,:VDFA,:VIFM,:VIFA]
            _put_start!(starts, nm, (jj,ii), 1.0)
        end
    end
    for kk in k
        for nm in [:PC,:PQ,:EtaC,:BudgetShare,:MuC,:AIDADSAlpha,:AIDADSBeta,:MargBudget]
            _put_start!(starts, nm, (kk,), 1.0)
        end
        for kk2 in k
            for nm in [:SigmaC,:DeltaC,:XiC,:EpsC]
                _put_start!(starts, nm, (kk,kk2), 1.0)
            end
        end
        for hh in h
            _put_start!(starts, :XH, (kk,hh), 1.0)
        end
    end
    for hh in h
        for nm in [:YH,:DeprY,:YD,:YC,:YSTAR,:CPIH]
            _put_start!(starts, nm, (hh,), 1.0)
        end
        _put_start!(starts, :SAV, (hh,), 0.1)
        for ii in i
            for nm in [:XAc,:PAc]
                _put_start!(starts, nm, (ii,hh), 1.0)
            end
        end
    end
    for ll in l
        _put_start!(starts, :LY, (ll,), get(PAR[:LSupply], ll, 1.0))
        _put_start!(starts, :MIGR, (ll,), 1.0)
        for gg in gz
            for nm in [:LS,:AVGW,:TW,:WMIN]
                _put_start!(starts, nm, (ll,gg), 1.0)
            end
            _put_start!(starts, :UE, (ll,gg), 0.05)
        end
        for ii in i
            _put_start!(starts, :EVFA, (ll,ii), 1.0)
        end
        for rr in r, rrp in rp
            _put_start!(starts, :MIG, (ll,rr,rrp), 1.0)
        end
    end
    for rr in r
        for nm in [:GDP,:RGDP,:CPI,:PGDP,:POP]
            _put_start!(starts, nm, (rr,), 1.0)
        end
        _put_start!(starts, :CA, (rr,), 0.0; raw=true)
        _put_start!(starts, :Sf, (rr,), 0.0; raw=true)
        _put_start!(starts, :WTOUT, (rr,), 1.0)
        for rrp in rp, ii in i
            for nm in [:PM,:PE,:WTFd,:WTFs,:WTFin,:WTFout,:WTFq,:TauPR,:WPE,:WPM,:AIDSSH,:PMa]
                _put_start!(starts, nm, (rr,rrp,ii), 1.0)
            end
        end
        for ii in i
            for nm in [:XM1,:PM1,:XM2,:PM2,:XDM,:PDM]
                _put_start!(starts, nm, (rr,ii), 1.0)
            end
        end
    end
    for ii in i, rr in r, rrp in rp
        for nm in [:XW,:PWM,:PWE]
            _put_start!(starts, nm, (ii,rr,rrp), 1.0)
        end
    end
    for ii in i, ff in f
        for nm in [:XDf,:XMf,:FDTax,:FMTax]
            _put_start!(starts, nm, (ii,ff), 1.0)
        end
    end
    for ff in f
        _put_start!(starts, :FD, (ff,), 1.0)
        for ii in i
            _put_start!(starts, :XAf, (ii,ff), 1.0)
        end
    end
    for tt in t
        for nm in [:RGDPMP,:PopDyn,:ChiL,:ChiT]
            _put_start!(starts, nm, (tt,), 1.0)
        end
    end
    return starts
end

# Initialization helpers for LCGE/LINKAGE JuMP models.
# These routines set JuMP start values from the balanced SAM and calibrated
# benchmark parameters. They do not fix variables; they only provide an NLP
# starting point close to the benchmark equilibrium.

function _safe_start_value!(model, name::Symbol, index_tuple::Tuple, value)
    if !haskey(model, name)
        return nothing
    end
    container = model[name]
    try
        var = isempty(index_tuple) ? container : container[index_tuple...]
        set_start_value(var, max(float(value), 1.0e-9))
    catch
        return nothing
    end
    return nothing
end

function _safe_start_value_raw!(model, name::Symbol, index_tuple::Tuple, value)
    if !haskey(model, name)
        return nothing
    end
    container = model[name]
    try
        var = isempty(index_tuple) ? container : container[index_tuple...]
        set_start_value(var, float(value))
    catch
        return nothing
    end
    return nothing
end



const LCGE_START_EPS = 1.0e-8
const LCGE_UE_START = 0.05
const LCGE_UE_MAX = 0.95

function _is_finite_number(x)
    return x isa Real && isfinite(float(x))
end

function enforce_nlp_safe_bounds_and_starts!(model; eps::Float64=LCGE_START_EPS)
    # PATH evaluates MCP mappings at trial points.  A lower bound of
    # exactly zero is dangerous in this model because many equations contain
    # ratios and powers such as P1/P2, P^(-sigma), and CES price indexes.  Move
    # nonnegative variables slightly inside the feasible region and repair any
    # missing/non-finite starts.
    for var in all_variables(model)
        try
            if has_lower_bound(var) && lower_bound(var) == 0.0
                set_lower_bound(var, eps)
            end
        catch
        end
        sv = try
            start_value(var)
        catch
            nothing
        end
        if sv === nothing || !(sv isa Real) || !isfinite(float(sv))
            try
                if has_lower_bound(var)
                    lb = lower_bound(var)
                    set_start_value(var, max(float(lb) + 1.0, eps))
                else
                    set_start_value(var, 0.0)
                end
            catch
            end
        elseif has_lower_bound(var) && float(sv) <= lower_bound(var)
            try
                set_start_value(var, lower_bound(var) + eps)
            catch
            end
        end
    end

    # Unemployment rates appear as (1 - UE) in nonlinear equations.  Keep their
    # starts and feasible range away from one to avoid zero/negative bases.
    if haskey(model, :UE)
        UE = model[:UE]
        try
            for key in eachindex(UE)
                set_lower_bound(UE[key], eps)
                set_upper_bound(UE[key], LCGE_UE_MAX)
                set_start_value(UE[key], LCGE_UE_START)
            end
        catch
        end
    end

    # RR is a utilization/rent ratio and appears in powers.  Keep it positive
    # and below one as intended by F-24.
    if haskey(model, :RR)
        RR = model[:RR]
        try
            for key in eachindex(RR)
                set_lower_bound(RR[key], eps)
                set_upper_bound(RR[key], 1.0)
                set_start_value(RR[key], 0.8)
            end
        catch
        end
    end

    # GammaInv appears inside (1 + GammaInv)^nstep.  Keep the base positive.
    if haskey(model, :GammaInv)
        try
            set_lower_bound(model[:GammaInv], -0.95)
            set_start_value(model[:GammaInv], 0.01)
        catch
        end
    end

    return model
end

function _maybe_lower_bound(var)
    try
        return has_lower_bound(var) ? lower_bound(var) : missing
    catch
        return missing
    end
end

function _maybe_upper_bound(var)
    try
        return has_upper_bound(var) ? upper_bound(var) : missing
    catch
        return missing
    end
end

function _maybe_start_value(var)
    try
        return start_value(var)
    catch
        return nothing
    end
end

function initialization_diagnostics(model; max_items::Int=25)
    rows = NamedTuple[]
    n_missing = 0
    n_bad = 0
    n_at_or_below_lb = 0
    for var in all_variables(model)
        nm = name(var)
        sv = _maybe_start_value(var)
        bad = sv === nothing || !(sv isa Real) || !isfinite(float(sv))
        lb = _maybe_lower_bound(var)
        ub = _maybe_upper_bound(var)
        atlb = lb !== missing && sv !== nothing && sv isa Real && float(sv) <= float(lb)
        n_missing += sv === nothing ? 1 : 0
        n_bad += bad ? 1 : 0
        n_at_or_below_lb += atlb ? 1 : 0
        if (bad || atlb) && length(rows) < max_items
            push!(rows, (variable=nm, start=sv, lower=lb, upper=ub,
                         issue=bad ? "missing_or_nonfinite_start" : "start_at_or_below_lower_bound"))
        end
    end
    return (missing_starts=n_missing,
            bad_starts=n_bad,
            starts_at_or_below_lower_bound=n_at_or_below_lb,
            examples=rows)
end

function check_initialization!(model; error_on_bad::Bool=true)
    d = initialization_diagnostics(model)
    if error_on_bad && (d.bad_starts > 0 || d.starts_at_or_below_lower_bound > 0)
        error("Bad model initialization: $(d). Call initialization_diagnostics(model) for details.")
    end
    return d
end

function initialize_from_sam!(model, data::LinkageData)
    default_sets!(data)
    S = data.sets
    i = S[:i]; j = S[:j]; k = S[:k]; r = S[:r]; rp = S[:rp]
    v = S[:v]; l = S[:l]; h = S[:h]; f = S[:f]; t = S[:t]
    gz = S[:gz]; e = S[:e]

    PAR = parameters(data)

    # Prices and price-like indexes: benchmark normalization.
    for name in [:PX, :PP, :PND, :PA, :Pfeed, :PKTEL, :PTFD, :PT, :PF,
                 :PC, :PQ, :PMT, :PD, :PET, :CPI, :PGDP]
        if haskey(model, name)
            obj = model[name]
            try
                for key in eachindex(obj)
                    set_start_value(obj[key], 1.0)
                end
            catch
            end
        end
    end
    for name in [:PNUM, :PABS, :PTLnd, :PFD, :WXMg, :WPMg, :WRR]
        _safe_start_value!(model, name, (), 1.0)
    end

    # Production benchmark quantities.
    for ii in i
        x0  = get(PAR[:output0], ii, 1.0)
        nd0 = get(PAR[:intermediate0], ii, 1.0)
        va0 = get(PAR[:value_added0], ii, 1.0)
        _safe_start_value!(model, :XP, (ii,), x0)
        _safe_start_value!(model, :XA, (ii,), x0)
        _safe_start_value!(model, :XD, (ii,), x0)
        _safe_start_value!(model, :XQ, (ii,), x0)
        _safe_start_value!(model, :XMT, (ii,), x0)
        _safe_start_value!(model, :XM, (ii,), max(0.05*x0, 1.0e-9))
        _safe_start_value!(model, :E,  (ii,), max(0.05*x0, 1.0e-9))
        _safe_start_value!(model, :D,  (ii,), max(0.90*x0, 1.0e-9))
        _safe_start_value!(model, :ND, (ii,), nd0)
        _safe_start_value!(model, :KF_d, (ii,), sum(get(PAR[:KSupply], (ii,vv), 1.0) for vv in v))
        _safe_start_value!(model, :AC, (ii,), 1.0)
        _safe_start_value!(model, :UVC, (ii,), 1.0)
        _safe_start_value!(model, :Nfirm, (ii,), 1.0)
        _safe_start_value!(model, :TFP, (ii,), 1.0)
        _safe_start_value!(model, :AEEI, (ii,), 1.0)
        for vv in v
            kval = get(PAR[:KSupply], (ii,vv), max(va0 / max(length(v),1), 1.0e-9))
            _safe_start_value!(model, :XPv, (ii,vv), max(x0 / max(length(v),1), 1.0e-9))
            _safe_start_value!(model, :VA, (ii,vv), max(va0 / max(length(v),1), 1.0e-9))
            _safe_start_value!(model, :Kvd, (ii,vv), kval)
            _safe_start_value!(model, :KT, (ii,vv), kval)
            _safe_start_value!(model, :KStock, (ii,vv), kval)
            _safe_start_value!(model, :INVK, (ii,vv), max(0.05*kval, 1.0e-9))
            _safe_start_value!(model, :R, (ii,vv), 1.0)
            _safe_start_value!(model, :NR, (ii,vv), 1.0)
            _safe_start_value!(model, :LambdaK, (ii,vv,first(t)), 1.0)
        end
        for ll in l
            _safe_start_value!(model, :LF_d, (ll,ii), max(get(PAR[:LSupply], ll, 1.0) / max(length(i),1), 1.0e-9))
            _safe_start_value!(model, :W, (ll,ii), 1.0)
            for tt in t
                _safe_start_value!(model, :LambdaL, (ll,ii,tt), 1.0)
            end
        end
        for tt in t
            _safe_start_value!(model, :LambdaT, (ii,tt), 1.0)
            _safe_start_value!(model, :LambdaF, (ii,tt), 1.0)
            _safe_start_value!(model, :ChiP, (ii,tt), 1.0)
            _safe_start_value!(model, :AlphaP, (ii,tt), 1.0)
            _safe_start_value!(model, :PhiP, (ii,tt), 1.0)
            for ee in e
                _safe_start_value!(model, :LambdaEP, (ee,ii,tt), 1.0)
            end
        end
        _safe_start_value!(model, :EtaP, (ii,), 1.0)
    end

    # Intermediate and final demand blocks.
    for jj in j, ii in i
        _safe_start_value!(model, :XAp, (jj,ii), max(get(PAR[:intermediate0], jj, 1.0) / max(length(i),1), 1.0e-9))
        _safe_start_value!(model, :PAp, (jj,ii), 1.0)
        _safe_start_value!(model, :XDp, (jj,ii), 1.0)
        _safe_start_value!(model, :XMp, (jj,ii), 1.0)
    end
    for kk in k, hh in h
        _safe_start_value!(model, :XH, (kk,hh), 1.0)
    end
    for hh in h
        _safe_start_value!(model, :YH, (hh,), 1.0)
        _safe_start_value!(model, :YD, (hh,), 1.0)
        _safe_start_value!(model, :YC, (hh,), 1.0)
        _safe_start_value!(model, :SAV, (hh,), 0.1)
    end
    for ll in l
        _safe_start_value!(model, :LY, (ll,), get(PAR[:LSupply], ll, 1.0))
        for gg in gz
            _safe_start_value!(model, :LS, (ll,gg), max(get(PAR[:LSupply], ll, 1.0) / max(length(gz),1), 1.0e-9))
            _safe_start_value!(model, :AVGW, (ll,gg), 1.0)
            _safe_start_value!(model, :TW, (ll,gg), 1.0)
            _safe_start_value!(model, :WMIN, (ll,gg), 1.0)
            _safe_start_value!(model, :UE, (ll,gg), 0.05)
        end
        _safe_start_value!(model, :MIGR, (ll,), 1.0)
    end

    # Bilateral trade starts.
    for ii in i, rr in r, rrp in rp
        _safe_start_value!(model, :PM, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :PE, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :XW, (ii,rr,rrp), 1.0)
        _safe_start_value!(model, :PWM, (ii,rr,rrp), 1.0)
        _safe_start_value!(model, :PWE, (ii,rr,rrp), 1.0)
        _safe_start_value!(model, :WTFd, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :WTFs, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :WTFin, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :WTFout, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :WTFq, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :TauPR, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :WPE, (rr,rrp,ii), 1.0)
        _safe_start_value!(model, :WPM, (rr,rrp,ii), 1.0)
    end

    # Macro/accounting starts.
    for name in [:TAXREV, :MTAXREV, :RMTAXREV, :GOVREV, :GEXP, :SAVE, :INVEST,
                 :TY, :FY, :KY, :TLnd, :PTLnd, :KS, :TR, :FDInv, :KActual, :GammaInv,
                 :KNorm, :PABS, :TarY, :RTarY, :YG, :InvSh, :WRR, :GDPMPr]
        _safe_start_value!(model, name, (), 1.0)
    end
    _safe_start_value_raw!(model, :GDEF, (), 0.0)
    _safe_start_value_raw!(model, :WALRAS, (), 0.0)
    _safe_start_value_raw!(model, :Sg, (), 0.0)
    _safe_start_value_raw!(model, :RSg, (), 0.0)
    for rr in r
        _safe_start_value_raw!(model, :CA, (rr,), 0.0)
        _safe_start_value!(model, :GDP, (rr,), 1.0)
        _safe_start_value!(model, :RGDP, (rr,), 1.0)
        _safe_start_value!(model, :POP, (rr,), 1.0)
        _safe_start_value_raw!(model, :Sf, (rr,), 0.0)
    end
    for tt in t
        _safe_start_value!(model, :RGDPMP, (tt,), 1.0)
        _safe_start_value!(model, :PopDyn, (tt,), 1.0)
        _safe_start_value!(model, :ChiL, (tt,), 1.0)
        _safe_start_value!(model, :ChiT, (tt,), 1.0)
    end

    enforce_nlp_safe_bounds_and_starts!(model)
    return model
end
