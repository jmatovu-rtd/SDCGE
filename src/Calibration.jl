# Usage:
#   data = init_data(); build_default_large_sam!(data); balance_sam_ras!(data)
#   calibrate_from_sam!(data)
#
# Calibrates base parameters from the balanced SAM and stores them in data.par.

function calibrate_from_sam!(data::LinkageData)
    default_sets!(data)
    if length(data.sam_accounts) == 0 || size(data.balanced_sam,1) == 0
        build_default_large_sam!(data)
        balance_sam_ras!(data)
    end
    M = data.balanced_sam
    S = data.sets; i = S[:i]; v = S[:v]; h = S[:h]
    idx = data.sam_index
    par = data.par

    output = Dict{Any,Float64}()
    interm = Dict{Any,Float64}()
    va = Dict{Any,Float64}()
    for p in i
        act = idx["ACT_"*p]
        output[p] = max(sum(M[:,act]), 1.0e-9)
        interm[p] = sum(M[idx["COM_"*q], act] for q in i)
        va[p] = output[p] - interm[p]
    end
    par[:output0] = output
    par[:intermediate0] = interm
    par[:value_added0] = va
    par[:intermediate_share] = Dict(p => interm[p] / output[p] for p in i)
    par[:value_added_share] = Dict(p => va[p] / output[p] for p in i)

    # Production CES shares used by ParameterTables/JuMP.
    par[:alpha_nd] = Dict((p,vv) => max(0.05, min(0.95, par[:intermediate_share][p])) for p in i for vv in v)
    par[:alpha_va] = Dict((p,vv) => max(0.05, min(0.95, par[:value_added_share][p])) for p in i for vv in v)
    par[:AT] = Dict(p => 1.0 for p in i)

    # Exogenous factor supplies from the balanced SAM. These are parameters, not JuMP variables.
    total_unsk = sum(M[idx["LAB_UNSK"], idx["ACT_"*p]] for p in i)
    total_sk   = sum(M[idx["LAB_SK"],   idx["ACT_"*p]] for p in i)
    par[:LSupply] = Dict("UnSkLab" => max(total_unsk, 1.0e-9),
                         "SkLab"   => max(total_sk,   1.0e-9))
    par[:KSupply] = Dict((p,vv) => max(M[idx["CAP"], idx["ACT_"*p]] / length(v), 1.0e-9) for p in i for vv in v)
    par[:TSupply] = Dict(p => max(M[idx["LAND"], idx["ACT_"*p]], 1.0e-9) for p in i)
    par[:FSupply] = Dict(p => max(M[idx["NRES"], idx["ACT_"*p]], 1.0e-9) for p in i)

    # Tax rates from SAM tax rows.
    par[:tau_p] = Dict(p => M[idx["TAX_OUT"], idx["ACT_"*p]] / output[p] for p in i)
    par[:tau_Ap] = Dict((q,p) => M[idx["TAX_INT"], idx["ACT_"*p]] / max(output[p],1.0e-9) for q in i for p in i)
    par[:tau_m] = Dict((r,rp,p) => M[idx["TAX_IMP"], idx["COM_"*p]] / max(sum(M[:,idx["COM_"*p]]),1.0e-9) for r in S[:r] for rp in S[:rp] for p in i)
    par[:tau_e] = Dict((r,rp,p) => M[idx["TAX_EXP"], idx["ROW"]] / max(sum(M[:,idx["ROW"]]),1.0e-9) for r in S[:r] for rp in S[:rp] for p in i)

    # Final demand shares.
    hh_col = idx["HH"]; gov_col = idx["GOV"]; inv_col = idx["INV"]
    total_hh = max(sum(M[idx["COM_"*p], hh_col] for p in i), 1.0e-9)
    par[:theta] = Dict((p,"HH") => M[idx["COM_"*p], hh_col] / total_hh for p in i)
    par[:mu] = Dict("HH" => 0.75)
    par[:govshare] = Dict(p => M[idx["COM_"*p], gov_col] / max(total_hh,1.0e-9) for p in i)
    par[:invshare] = Dict(p => M[idx["COM_"*p], inv_col] / max(total_hh,1.0e-9) for p in i)

    return data
end
