# Usage: add_factor_equations!(model, data, PAR)
# Complete paper-numbered LINKAGE factor-market equations (F-1)--(F-33).
# MCP form: residual ⟂ left-hand/market-clearing variable.

function _lcge_badfinite(x)
    return !isfinite(float(x))
end

function add_factor_equations!(model, data::LinkageData, PAR)
    S = data.sets
    default_sets!(data)
    i = S[:i]; v = S[:v]; l = S[:l]; r = S[:r]; rp = S[:rp]; gz = S[:gz]; gs = S[:gs]
    ag = S[:ag]

    W = model[:W]; LV = model[:LV]; LF_d = model[:LF_d]; Nfirm = model[:Nfirm]
    LS = model[:LS]; MIGR = model[:MIGR]; AVGW = model[:AVGW]; NW = model[:NW]; TW = model[:TW]; WMIN = model[:WMIN]; UE = model[:UE]
    PS = model[:PS]; PABS = model[:PABS]
    Td = model[:Td]; Ts = model[:Ts]; PT = model[:PT]; NPT = model[:NPT]; TLnd = model[:TLnd]; PTLnd = model[:PTLnd]
    Fd = model[:Fd]; Fs = model[:Fs]; PF = model[:PF]
    Kvd = model[:Kvd]; KF_d = model[:KF_d]; R = model[:R]; NR = model[:NR]; KSs = model[:KSs]; KS = model[:KS]; TR = model[:TR]
    RR = model[:RR]; CHIv = model[:CHIv]; K0 = model[:K0]; XP = model[:XP]; XPv = model[:XPv]
    FDInv = model[:FDInv]; KActual = model[:KActual]; GammaInv = model[:GammaInv]; KNorm = model[:KNorm]

    # Pre-compute all regime switches outside JuMP macros.
    migr_integrated = [ll for ll in l if _lcge_badfinite(PAR[:omega_migr][ll])]
    migr_segmented  = [ll for ll in l if !_lcge_badfinite(PAR[:omega_migr][ll])]
    eta_T_inf = _lcge_badfinite(PAR[:eta_T])
    lndmax_inf = _lcge_badfinite(PAR[:LndMAX])
    omega_T_inf = _lcge_badfinite(PAR[:omega_T])
    omega_K_inf = _lcge_badfinite(PAR[:omega_K])
    omega_F_inf = [ii for ii in i if _lcge_badfinite(PAR[:omega_F][ii])]
    omega_F_fin = [ii for ii in i if !_lcge_badfinite(PAR[:omega_F][ii])]

    # (F-1) Rural labor supply.
    @constraint(model, F_1[ll in l], (LS[ll,"rural"]) - ((1 + PAR[:g_l][(ll,"rural")]) * PAR[:LS0][(ll,"rural")] - MIGR[ll]) ⟂ LS[ll,"rural"])

    # (F-2) Urban labor supply.
    @constraint(model, F_2[ll in l], (LS[ll,"urban"]) - ((1 + PAR[:g_l][(ll,"urban")]) * PAR[:LS0][(ll,"urban")] + MIGR[ll]) ⟂ LS[ll,"urban"])

    # (F-3) National labor supply.
    @constraint(model, F_3[ll in l], (LS[ll,"national"]) - (sum(LS[ll,gg] for gg in gs)) ⟂ LS[ll,"national"])

    # (F-4) Average wage in each zone.
    @constraint(model, F_4[ll in l, gg in gz],
        (AVGW[ll,gg] * (sum(LV[ll,ii] + Nfirm[ii] * LF_d[ll,ii] for ii in i) + 1.0e-9)) -
        (sum(NW[ll,ii] * (LV[ll,ii] + Nfirm[ii] * LF_d[ll,ii]) for ii in i)) ⟂ AVGW[ll,gg])

    # (F-5) Rural-to-urban migration. No regime test appears inside the JuMP expression.
    @constraint(model, F_5_fixed_migration[ll in migr_integrated],
        (MIGR[ll]) - 0.0 ⟂ MIGR[ll])

    @constraint(model, F_5_migration[ll in migr_segmented],
        (MIGR[ll]) -
        (PAR[:chi_migr][ll] *
         (((1 - UE[ll,"urban"]) * AVGW[ll,"urban"]) /
          (((1 - UE[ll,"rural"]) * AVGW[ll,"rural"]) + 1.0e-9)) ^ PAR[:omega_migr][ll]) ⟂ MIGR[ll])

    # (F-6) National wage condition.
    @constraint(model, F_6_integrated[ll in migr_integrated],
        ((TW[ll,"national"] - WMIN[ll,"national"]) * UE[ll,"national"]) - 0.0 ⟂ UE[ll,"national"])
    @constraint(model, F_6_segmented[ll in migr_segmented],
        (TW[ll,"national"]) - (AVGW[ll,"national"]) ⟂ TW[ll,"national"])

    # (F-7) Market-specific wage condition.
    @constraint(model, F_7_integrated[ll in migr_integrated, gg in gs],
        (TW[ll,gg]) - (TW[ll,"national"]) ⟂ TW[ll,gg])
    @constraint(model, F_7_segmented[ll in migr_segmented, gg in gs],
        ((TW[ll,gg] - WMIN[ll,gg]) * UE[ll,gg]) - 0.0 ⟂ UE[ll,gg])

    # (F-8) National minimum wage.
    @constraint(model, F_8[ll in migr_integrated],
        (WMIN[ll,"national"]) - (PAR[:chi_wmin][(ll,"national")] *
        PS["national"]^PAR[:omega_ps]["national"] *
        PABS^PAR[:omega_p]["national"] *
        (1 - UE[ll,"national"])^PAR[:omega_ue]["national"]) ⟂ WMIN[ll,"national"])

    # (F-9) Regional minimum wage.
    @constraint(model, F_9_integrated[ll in migr_integrated, gg in gs],
        (WMIN[ll,gg]) - (WMIN[ll,"national"]) ⟂ WMIN[ll,gg])
    @constraint(model, F_9_segmented[ll in migr_segmented, gg in gs],
        (WMIN[ll,gg]) - (PAR[:chi_wmin][(ll,gg)] *
        PS[gg]^PAR[:omega_ps][gg] *
        PABS^PAR[:omega_p][gg] *
        (1 - UE[ll,gg])^PAR[:omega_ue][gg]) ⟂ WMIN[ll,gg])

    # (F-10) Unemployment rate by zone.
    @constraint(model, F_10[ll in l, gg in gz],
        (UE[ll,gg] * (LS[ll,gg] + 1.0e-9)) -
        (LS[ll,gg] - sum(LV[ll,ii] + Nfirm[ii] * LF_d[ll,ii] for ii in i)) ⟂ UE[ll,gg])

    # (F-11) Sectoral net wages.
    @constraint(model, F_11[ll in l, ii in i], (NW[ll,ii]) - (PAR[:phi_wage][(ll,ii)] * TW[ll,"national"]) ⟂ NW[ll,ii])

    # (F-12) Employer wage inclusive of wage tax.
    @constraint(model, F_12[ll in l, ii in i], (W[ll,ii]) - ((1 + PAR[:tau_l][(ll,ii)]) * NW[ll,ii]) ⟂ W[ll,ii])

    # (F-13) Aggregate land supply.
    if eta_T_inf
        @constraint(model, F_13_inf_eta, (PTLnd - PABS * PAR[:PTLnd0]) - 0.0 ⟂ PTLnd)
    elseif lndmax_inf
        @constraint(model, F_13_unbounded_land,
            (TLnd - PAR[:chi_T][:land] * (PTLnd / (PABS + 1.0e-9)) ^ PAR[:eta_T]) - 0.0 ⟂ TLnd)
    else
        @constraint(model, F_13_bounded_land,
            (TLnd - PAR[:LndMAX] / (1 + PAR[:chi_T][:land] * exp(-PAR[:gamma_ts] * (PTLnd / (PABS + 1.0e-9))))) - 0.0 ⟂ TLnd)
    end

    # (F-14) Aggregate land price / land-market closure.
    if omega_T_inf
        @constraint(model, F_14_mobile_land, (TLnd) - (sum(Td[ii] for ii in ag)) ⟂ TLnd)
    else
        @constraint(model, F_14_cet_land,
            (PTLnd - (sum(PAR[:gamma_T][ii] * PT[ii]^(1 + PAR[:omega_T]) for ii in ag))^(1 / (1 + PAR[:omega_T]))) - 0.0 ⟂ PTLnd)
    end

    # (F-15) Sectoral land allocation.
    if omega_T_inf
        @constraint(model, F_15_mobile_land[ii in ag], (PT[ii]) - (PTLnd) ⟂ PT[ii])
    else
        @constraint(model, F_15_cet_land[ii in ag],
            (Ts[ii] - PAR[:gamma_T][ii] * (PT[ii] / (PTLnd + 1.0e-9)) ^ PAR[:omega_T] * TLnd) - 0.0 ⟂ Ts[ii])
    end

    # (F-16) Sectoral land-market equilibrium.
    @constraint(model, F_16[ii in ag], (Td[ii]) - (Ts[ii]) ⟂ Td[ii])

    # (F-17) Land tax wedge.
    @constraint(model, F_17[ii in ag], (PT[ii]) - ((1 + PAR[:tau_t][ii]) * NPT[ii]) ⟂ PT[ii])

    # (F-18) Sector-specific factor supply / fixed real factor price.
    @constraint(model, F_18_fixed_factor[ii in omega_F_inf],
        (PF[ii] - PABS * PAR[:PF0][ii]) - 0.0 ⟂ PF[ii])
    @constraint(model, F_18_supply_factor[ii in omega_F_fin],
        (Fs[ii] - PAR[:chi_F][ii] * (PF[ii] / (PABS + 1.0e-9)) ^ PAR[:omega_F][ii]) - 0.0 ⟂ Fs[ii])

    # (F-19) Sector-specific factor market equilibrium.
    @constraint(model, F_19[ii in i], (Fs[ii]) - (Fd[ii]) ⟂ Fs[ii])

    # (F-20) Single-vintage capital supply allocation / law of one price.
    if omega_K_inf
        @constraint(model, F_20_mobile_capital[ii in i], (R[ii,"Old"]) - (TR) ⟂ R[ii,"Old"])
    else
        @constraint(model, F_20_cet_capital[ii in i],
            (KSs[ii] - PAR[:gamma_K][ii] * (R[ii,"Old"] / (TR + 1.0e-9)) ^ PAR[:omega_K] * KS) - 0.0 ⟂ KSs[ii])
    end

    # (F-21) Economy-wide capital return / aggregate capital-market closure.
    if omega_K_inf
        @constraint(model, F_21_mobile_capital,
            (sum(sum(Kvd[ii,vv] for vv in v) + Nfirm[ii] * KF_d[ii] for ii in i)) - (KS) ⟂ KS)
    else
        @constraint(model, F_21_cet_capital,
            (TR - (sum(PAR[:gamma_K][ii] * R[ii,"Old"]^(1 + PAR[:omega_K]) for ii in i))^(1 / (1 + PAR[:omega_K]))) - 0.0 ⟂ TR)
    end

    # (F-22) Single-vintage sectoral capital-market equilibrium.
    @constraint(model, F_22[ii in i], (sum(Kvd[ii,vv] for vv in v) + Nfirm[ii] * KF_d[ii]) - (KSs[ii]) ⟂ KSs[ii])

    # (F-23) Capital-output ratio by vintage.
    @constraint(model, F_23[ii in i, vv in v], (CHIv[ii,vv] * XPv[ii,vv]) - (Kvd[ii,vv]) ⟂ CHIv[ii,vv])

    # (F-24) Old-capital supply schedule and RR bound.
    @constraint(model, F_24_old_supply[ii in i], (CHIv[ii,"Old"] * XP[ii]) - (K0[ii] * RR[ii]^PAR[:eta_k]) ⟂ CHIv[ii,"Old"])
    @constraint(model, F_24_rr_bound[ii in i], (1.0) - (RR[ii]) ⟂ RR[ii])

    # (F-25) Multiple-vintage aggregate capital-market equilibrium.
    @constraint(model, F_25,
        (sum(Kvd[ii,vv] for ii in i for vv in v) + sum(Nfirm[ii] * KF_d[ii] for ii in i)) - (KS) ⟂ KActual)

    # (F-26) Net return on Old capital.
    @constraint(model, F_26[ii in i], (NR[ii,"Old"]) - (RR[ii] * TR) ⟂ NR[ii,"Old"])

    # (F-27) Net return on New capital.
    @constraint(model, F_27[ii in i], (NR[ii,"New"]) - (TR) ⟂ NR[ii,"New"])

    # (F-28) Gross capital return inclusive of capital tax wedge.
    @constraint(model, F_28[ii in i, vv in v], (R[ii,vv]) - ((1 + PAR[:tau_k][(ii,vv)]) * NR[ii,vv]) ⟂ R[ii,vv])

    # (F-29) Aggregate output across vintages.
    @constraint(model, F_29[ii in i], (XP[ii]) - (sum(XPv[ii,vv] for vv in v)) ⟂ XP[ii])

    # (F-30) Old-vintage output from installed old capital and relative return.
    @constraint(model, F_30[ii in i], (XPv[ii,"Old"] * CHIv[ii,"Old"]) - (K0[ii] * RR[ii]^PAR[:eta_k]) ⟂ XPv[ii,"Old"])

    # (F-31) Investment growth factor implicit equation.
    @constraint(model, F_31, (FDInv) - ((1 + GammaInv)^PAR[:nstep] * PAR[:INVEST0]) ⟂ FDInv)

    # (F-32) Capital accumulation over an n-period step.
    @constraint(model, F_32,
        (KActual) - ((1 - PAR[:delta])^PAR[:nstep] * PAR[:KSupply][(first(i),"Old")] +
        (((1 + GammaInv)^PAR[:nstep] - (1 - PAR[:delta])^PAR[:nstep]) / (GammaInv + PAR[:delta] + 1.0e-9)) * PAR[:INVEST0]) ⟂ KActual)

    # (F-33) Normalized capital stock.
    @constraint(model, F_33,
        (KNorm / (KActual + 1.0e-9)) - (KS / (PAR[:KSupply][(first(i),"Old")] + 1.0e-9)) ⟂ KNorm)

    return model
end
