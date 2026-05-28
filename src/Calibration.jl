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

    # Baseline OLD-vintage capital stock per sector (matches KSupply[(p,"Old")]).
    # F_30 (XPv[Old]*CHIv[Old] = K0 * RR^eta_k) holds at benchmark when RR=1 and
    # K0 equals the old-vintage capital demand Kvd[Old] = KSupply[(p,"Old")].
    par[:K0] = Dict(p => max(M[idx["CAP"], idx["ACT_"*p]] / length(v), 1.0e-9) for p in i)

    # Final-demand column indices and total household consumption from SAM.
    hh_col = idx["HH"]; gov_col = idx["GOV"]; inv_col = idx["INV"]
    total_hh = max(sum(M[idx["COM_"*p], hh_col] for p in i), 1.0e-9)

    # Aggregate factor-income anchors used in income equations Y_1..Y_4.
    par[:TY0] = max(sum(M[idx["LAND"], idx["ACT_"*p]] for p in i), 1.0e-9)
    par[:FY0] = max(sum(M[idx["NRES"], idx["ACT_"*p]] for p in i), 1.0e-9)
    par[:KY0] = max(sum(M[idx["CAP"],  idx["ACT_"*p]] for p in i), 1.0e-9)
    par[:LY0] = Dict("UnSkLab" => max(total_unsk, 1.0e-9),
                     "SkLab"   => max(total_sk,   1.0e-9))

    # GDP at producer prices = sum of gross output (matches M_1 definition).
    par[:GDP0] = max(sum(output[p] for p in i), 1.0e-9)
    par[:RGDP0] = par[:GDP0]
    par[:PGDP0] = 1.0

    # Investment and government expenditure benchmarks from SAM final demand columns.
    par[:INVEST0] = max(sum(M[idx["COM_"*p], inv_col] for p in i), 1.0e-9)
    par[:GOV0]    = max(sum(M[idx["COM_"*p], gov_col] for p in i), 1.0e-9)
    par[:HH0]     = max(total_hh, 1.0e-9)

    # Household income from SAM = labor + capital + land + natural resources.
    par[:YH0] = Dict(hh => max(
        sum(M[idx["LAB_UNSK"], idx["ACT_"*p]] for p in i) +
        sum(M[idx["LAB_SK"],   idx["ACT_"*p]] for p in i) +
        sum(M[idx["CAP"],      idx["ACT_"*p]] for p in i) +
        sum(M[idx["LAND"],     idx["ACT_"*p]] for p in i) +
        sum(M[idx["NRES"],     idx["ACT_"*p]] for p in i), 1.0e-9) for hh in h)

    # Government revenue from SAM (sum of tax rows).
    yg_total = 0.0
    for t in data.sam_accounts[:taxes]
        yg_total += sum(M[idx[t], :])
    end
    par[:YG0] = max(yg_total, 1.0e-9)

    # Government share of GDP (calibrates C_6: FD[Gov] = chi_gov * GDPMPr).
    par[:chi_gov] = par[:GOV0] / par[:GDP0]

    # Government saving / deficit at benchmark = revenue − expenditure.
    par[:Sg0] = par[:YG0] - par[:GOV0]

    # Labor supply by zone: split total LSupply between rural and urban,
    # so F_1 / F_2 (LS[zone] = LS0[zone] + MIGR) and F_3 (LS[national] = sum) hold.
    par[:LS0] = Dict{Any,Float64}()
    for ll in S[:l]
        par[:LS0][(ll, "rural")]    = par[:LSupply][ll] / 2
        par[:LS0][(ll, "urban")]    = par[:LSupply][ll] / 2
        par[:LS0][(ll, "national")] = par[:LSupply][ll]
    end

    # Sector-level intermediate-input quantities from SAM (used to start XAp / ND).
    par[:XAp0] = Dict((q,p) => max(M[idx["COM_"*q], idx["ACT_"*p]], 1.0e-9)
                       for q in i for p in i)

    # Household consumption per commodity from SAM (used to start XAc).
    par[:XAc0] = Dict((p,hh) => max(M[idx["COM_"*p], hh_col], 1.0e-9)
                       for p in i for hh in h)

    # Government and investment demand per commodity from SAM (used to start XAf).
    par[:XAf0] = Dict((p,"Gov") => max(M[idx["COM_"*p], gov_col], 1.0e-9) for p in i)
    for p in i
        par[:XAf0][(p,"Inv")] = max(M[idx["COM_"*p], inv_col], 1.0e-9)
    end

    # Tax rates from SAM tax rows.
    par[:tau_p] = Dict(p => M[idx["TAX_OUT"], idx["ACT_"*p]] / output[p] for p in i)
    par[:tau_Ap] = Dict((q,p) => M[idx["TAX_INT"], idx["ACT_"*p]] / max(output[p],1.0e-9) for q in i for p in i)
    par[:tau_m] = Dict((r,rp,p) => M[idx["TAX_IMP"], idx["COM_"*p]] / max(sum(M[:,idx["COM_"*p]]),1.0e-9) for r in S[:r] for rp in S[:rp] for p in i)
    par[:tau_e] = Dict((r,rp,p) => M[idx["TAX_EXP"], idx["ROW"]] / max(sum(M[:,idx["ROW"]]),1.0e-9) for r in S[:r] for rp in S[:rp] for p in i)

    # Final demand shares.
    par[:theta] = Dict((p,"HH") => M[idx["COM_"*p], hh_col] / total_hh for p in i)
    par[:mu] = Dict("HH" => 0.75)
    par[:govshare] = Dict(p => M[idx["COM_"*p], gov_col] / max(total_hh,1.0e-9) for p in i)
    par[:invshare] = Dict(p => M[idx["COM_"*p], inv_col] / max(total_hh,1.0e-9) for p in i)

    # Land-supply scale parameter: F_13 says TLnd = chi_T * (PTLnd/PABS)^eta_T,
    # so chi_T[land] should equal the SAM-implied benchmark land supply.
    par[:chi_T] = Dict(:land => max(sum(values(par[:TSupply])), 1.0e-9))

    # Sector-specific natural-resource scale parameter: F_18 (omega_F finite branch)
    # says Fs[i] = chi_F[i] * (PF/PABS)^omega_F, so chi_F[i] = FSupply[i] at benchmark.
    par[:chi_F] = Dict(p => max(get(par[:FSupply], p, 1.0e-9), 1.0e-9) for p in i)

    # Per-sector labor demand distribution (used to initialize LV).
    par[:LV0] = Dict{Any,Float64}()
    for ll in S[:l], p in i
        sam_row = ll == "UnSkLab" ? "LAB_UNSK" : "LAB_SK"
        par[:LV0][(ll, p)] = max(M[idx[sam_row], idx["ACT_"*p]], 1.0e-9)
    end

    # Input-output coefficients a_nd[j,i]: share of input j in sector i's intermediate bundle.
    # At benchmark: XAp[j,i] = a_nd[j,i] * ND[i], with ND[i] = intermediate0[i] and
    # XAp[j,i] = M[COM_j, ACT_i] from SAM. So a_nd[j,i] = M[COM_j, ACT_i] / intermediate0[i].
    par[:a_nd] = Dict{Any,Float64}()
    for jj in i, ii in i
        nd_total = max(par[:intermediate0][ii], 1.0e-9)
        par[:a_nd][(jj, ii)] = max(M[idx["COM_"*jj], idx["ACT_"*ii]], 0.0) / nd_total
    end

    # Final-demand share coefficients a_f[i,f]: share of good i in fund f.
    # At benchmark: XAf[i,f] = a_f[(i,f)] * FD[f], so a_f[(i,f)] = SAM_value / FD[f].
    par[:a_f] = Dict{Any,Float64}()
    gov_total = max(par[:GOV0], 1.0e-9)
    inv_total = max(par[:INVEST0], 1.0e-9)
    for p in i
        par[:a_f][(p, "Gov")] = max(M[idx["COM_"*p], gov_col], 0.0) / gov_total
        par[:a_f][(p, "Inv")] = max(M[idx["COM_"*p], inv_col], 0.0) / inv_total
    end

    # Trade-margin shares a_Mg[r,i]: share of good i supplied as trade-margin to region r.
    # Default placeholder uniform; calibrate from SAM trade-margin row if available.
    # (left at default for now — only sectors P081-P100 supply margins in the synthetic SAM)

    # XA0[i]: domestic Armington demand at benchmark = total uses MINUS exports.
    par[:XA0] = Dict{Any,Float64}()
    for p in i
        com = idx["COM_"*p]
        dom_uses = sum(max(M[com, idx["ACT_"*q]], 0.0) for q in i) +
                   max(M[com, hh_col], 0.0) + max(M[com, gov_col], 0.0) +
                   max(M[com, inv_col], 0.0)
        par[:XA0][p] = max(dom_uses, 1.0e-9)
    end

    # ── CET share parameters calibrated so aggregate prices equal 1 at benchmark ──
    # gamma_T[i]: land CET share (in F_14 CES dual / F_15 sectoral allocation).
    #   At benchmark with PT=PTLnd=1: Σ_ag gamma_T must equal 1.
    par[:gamma_T] = Dict{Any,Float64}()
    tot_land = sum(get(par[:TSupply], p, 0.0) for p in S[:ag])
    for p in i
        par[:gamma_T][p] = (p in S[:ag] && tot_land > 1.0e-9) ?
            get(par[:TSupply], p, 0.0) / tot_land : 0.0
    end

    # gamma_K[i]: capital CET share (in F_21_cet_capital across all sectors).
    par[:gamma_K] = Dict{Any,Float64}()
    tot_cap_old = sum(get(par[:KSupply], (p,"Old"), 0.0) for p in i)
    for p in i
        par[:gamma_K][p] = tot_cap_old > 1.0e-9 ?
            get(par[:KSupply], (p,"Old"), 0.0) / tot_cap_old : 1.0/length(i)
    end

    # ── Production-nest CES cost shares calibrated from SAM payment cells ──────
    # Total fertilizer / energy intermediate cost per sector (from SAM).
    fert_set = S[:ft]; e_set = S[:e]
    fert_cost = Dict(p => sum(M[idx["COM_"*f], idx["ACT_"*p]] for f in fert_set) for p in i)
    enrg_cost = Dict(p => sum(M[idx["COM_"*e], idx["ACT_"*p]] for e in e_set) for p in i)
    # Store for use in Initialization.jl (per-sector fert and energy demand starts).
    par[:fert0] = fert_cost
    par[:enrg0] = enrg_cost
    par[:alpha_l]     = Dict{Any,Float64}()  # ULD share in VA
    par[:alpha_hktef] = Dict{Any,Float64}()  # HKTEF share in VA = 1 − alpha_l (crops)
    par[:alpha_h]     = Dict{Any,Float64}()  # SLD share in HKT
    par[:alpha_kt]    = Dict{Any,Float64}()  # KT share in HKT = 1 − alpha_h
    par[:alpha_fert]  = Dict{Any,Float64}()  # fert share in HKTEF (crops)
    par[:alpha_hkte]  = Dict{Any,Float64}()  # HKTE share in HKTEF = 1 − alpha_fert
    par[:alpha_e]     = Dict{Any,Float64}()  # XEp share in HKTE
    par[:alpha_hkt]   = Dict{Any,Float64}()  # HKT share in HKTE = 1 − alpha_e
    for p in i, vv in v
        # Per-sector cost components at benchmark (SAM values).
        uld   = max(M[idx["LAB_UNSK"], idx["ACT_"*p]], 0.0)
        sld   = max(M[idx["LAB_SK"],   idx["ACT_"*p]], 0.0)
        kvd_v = max(get(par[:KSupply], (p,vv), 0.0), 0.0)
        land  = p in S[:ag] ? max(get(par[:TSupply], p, 0.0), 0.0) : 0.0
        nres  = max(get(par[:FSupply], p, 0.0), 0.0)
        fert  = p in S[:cr] ? max(fert_cost[p], 0.0) : 0.0
        enrg  = max(enrg_cost[p], 0.0)
        # Sum across both vintages for the labor / land totals (not per-vintage).
        KT    = kvd_v + (p in S[:lv] ? 0.0 : land/length(v)) + nres/length(v)
        HKT   = KT + sld/length(v)
        HKTE  = HKT + enrg/length(v)
        HKTEF = HKTE + fert/length(v)
        VA    = HKTEF + uld/length(v)
        # CES shares = cost shares at benchmark (sum to 1 within each pair).
        par[:alpha_l][(p,vv)]     = VA    > 0 ? (uld/length(v)) / VA    : 0.30
        par[:alpha_hktef][(p,vv)] = VA    > 0 ? HKTEF / VA               : 0.70
        par[:alpha_fert][(p,vv)]  = HKTEF > 0 ? (fert/length(v)) / HKTEF : 0.05
        par[:alpha_hkte][(p,vv)]  = HKTEF > 0 ? HKTE / HKTEF              : 0.95
        par[:alpha_e][(p,vv)]     = HKTE  > 0 ? (enrg/length(v)) / HKTE  : 0.05
        par[:alpha_hkt][(p,vv)]   = HKTE  > 0 ? HKT / HKTE                : 0.95
        par[:alpha_h][(p,vv)]     = HKT   > 0 ? (sld/length(v)) / HKT    : 0.10
        par[:alpha_kt][(p,vv)]    = HKT   > 0 ? KT / HKT                  : 0.90
    end

    # Capital-land-natural-resource CES shares per (sector, vintage) calibrated
    # from SAM factor payments. Resolves Y_1/Y_2 inflation by ensuring Td≈TSupply,
    # Fd≈FSupply at benchmark (so land/NR prices stay at 1).
    par[:alpha_k]  = Dict{Any,Float64}()
    par[:alpha_t]  = Dict{Any,Float64}()
    par[:alpha_ff] = Dict{Any,Float64}()
    for p in i, vv in v
        cap_v = max(get(par[:KSupply], (p,vv), 0.0), 0.0)
        land  = max(get(par[:TSupply], p, 0.0), 0.0)
        nres  = max(get(par[:FSupply], p, 0.0), 0.0)
        # Land enters the capital nest only for agricultural sectors.
        if !(p in S[:ag]); land = 0.0; end
        total = cap_v + land + nres
        if total > 1.0e-9
            par[:alpha_k][(p,vv)]  = cap_v / total
            par[:alpha_t][(p,vv)]  = land  / total
            par[:alpha_ff][(p,vv)] = nres  / total
        else
            par[:alpha_k][(p,vv)]  = 0.95
            par[:alpha_t][(p,vv)]  = 0.0
            par[:alpha_ff][(p,vv)] = 0.05
        end
    end

    # Armington domestic/import shares per sector (calibrated from SAM commodity
    # column: domestic = activity supply, import = ROW supply to commodity).
    row_idx = idx["ROW"]
    par[:beta_d] = Dict{Any,Float64}()
    par[:beta_m] = Dict{Any,Float64}()
    for p in i
        com = idx["COM_"*p]
        act = idx["ACT_"*p]
        dom_supply = max(M[act, com], 0.0)            # domestic activity supplies COM_p
        imp_supply = max(M[row_idx, com], 0.0)        # imports from ROW
        total = dom_supply + imp_supply
        if total > 1.0e-9
            par[:beta_d][p] = dom_supply / total
            par[:beta_m][p] = imp_supply / total
        else
            par[:beta_d][p] = 0.92
            par[:beta_m][p] = 0.08
        end
    end

    # CET domestic vs export shares per sector (calibrated from SAM commodity row).
    # XDs is the share of output staying domestic; ES is the share exported.
    par[:beta_xd] = Dict{Any,Float64}()
    par[:beta_es] = Dict{Any,Float64}()
    for p in i
        com = idx["COM_"*p]
        exp_demand  = max(M[com, row_idx], 0.0)       # exports to ROW
        dom_demand  = sum(max(M[com, c], 0.0) for c in 1:size(M,2)) - exp_demand
        total = dom_demand + exp_demand
        if total > 1.0e-9
            par[:beta_xd][p] = dom_demand / total
            par[:beta_es][p] = exp_demand / total
        else
            par[:beta_xd][p] = 0.95
            par[:beta_es][p] = 0.05
        end
    end

    # ELES marginal propensity to consume (mu_c) calibrated so household savings
    # match the SAM:  SAV_bench = (1 − Σ mu_c) · (YC − min_bundle).
    # Resolves the D_3 vs C_9 tension where Σmu_c=1 forces SAV=0.
    DeprY_bench = 0.05 * par[:KY0]
    SAV_bench = par[:INVEST0] - DeprY_bench - par[:Sg0]
    LY_total  = sum(values(par[:LY0]))
    YH_bench  = par[:TY0] + par[:FY0] + LY_total + par[:KY0] - DeprY_bench
    YC_bench  = YH_bench - SAV_bench
    # min_bundle = popH * sum(theta) ≈ 1.0 (popH=1, theta normalized).
    min_bundle = sum(values(par[:theta]))
    sum_mu_target = 1.0 - SAV_bench / max(YC_bench - min_bundle, 1.0e-9)
    sum_mu_target = clamp(sum_mu_target, 0.05, 0.95)
    # Distribute uniformly across bundles (each bundle gets equal MPC).
    par[:mu_c] = Dict((kk, hh) => sum_mu_target / length(S[:k])
                       for kk in S[:k] for hh in h)

    return data
end
