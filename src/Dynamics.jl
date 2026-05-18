# Usage: add_dynamic_equations!(model, data, PAR)
# Complete paper-numbered LINKAGE dynamic and Annex-G AIDADS equations (G-1)--(G-30).

function add_dynamic_equations!(model, data::LinkageData, PAR)
    S=data.sets; default_sets!(data)
    i=S[:i]; k=S[:k]; e=S[:e]; v=S[:v]; l=S[:l]; t=S[:t]
    ik=S[:ip]; ink=S[:ag]

    RGDPMP=model[:RGDPMP]; LambdaL=model[:LambdaL]; LambdaK=model[:LambdaK]; LambdaT=model[:LambdaT]; LambdaF=model[:LambdaF]; LambdaEP=model[:LambdaEP]
    ChiP=model[:ChiP]; AlphaP=model[:AlphaP]; EtaP=model[:EtaP]; PhiP=model[:PhiP]
    PopDyn=model[:PopDyn]; ChiL=model[:ChiL]; ChiT=model[:ChiT]; ChiF=model[:ChiF]; K0=model[:K0]; Kvd=model[:Kvd]
    E=model[:E]; XP=model[:XP]
    EtaC=model[:EtaC]; BudgetShare=model[:BudgetShare]; MuC=model[:MuC]; AIDADSAlpha=model[:AIDADSAlpha]; AIDADSBeta=model[:AIDADSBeta]; MargBudget=model[:MargBudget]
    SigmaC=model[:SigmaC]; DeltaC=model[:DeltaC]; XiC=model[:XiC]; EpsC=model[:EpsC]; LambdaAIDADS=model[:LambdaAIDADS]
    XH=model[:XH]; PC=model[:PC]; YC=model[:YC]

    # (G-1) Target path for real GDP at market prices.
    @constraint(model, G_1[tt in t], (RGDPMP[tt]) - ((1 + PAR[:g_y][tt])^PAR[:nstep] * PAR[:RGDPMP0][tt]) ⟂ RGDPMP[tt])

    # (G-2) Labor-augmenting productivity for endogenous-productivity sectors.
    @constraint(model, G_2[ll in l, ii in ik, tt in t], (LambdaL[ll,ii,tt]) - ((1 + PAR[:gamma_l][tt] + ChiP[ii,tt] + PAR[:pi_dyn][(ii,tt)])^PAR[:nstep] * PAR[:lambda_l0][(ll,ii,tt)]) ⟂ LambdaL[ll,ii,tt])

    # (G-3) Openness-sensitive productivity component.
    @constraint(model, G_3[ii in i, tt in t], (ChiP[ii,tt]) - (PhiP[ii,tt] * (E[ii] / (XP[ii] + 1.0e-9))^PAR[:eta_p][ii]) ⟂ ChiP[ii,tt])

    # (G-4) Baseline calibration of the openness productivity share.
    @constraint(model, G_4[ii in ik, tt in t], (ChiP[ii,tt]) - (AlphaP[ii,tt] * (PAR[:gamma_l][tt] + ChiP[ii,tt] + PAR[:pi_dyn][(ii,tt)])) ⟂ ChiP[ii,tt])

    # (G-5) Labor productivity in exogenous-productivity sectors.
    @constraint(model, G_5[ll in l, ii in ink, tt in t], (LambdaL[ll,ii,tt]) - ((1 + ChiP[ii,tt] + (1 - AlphaP[ii,tt]) * PAR[:gamma_s][(ii,tt)])^PAR[:nstep] * PAR[:lambda_l0][(ll,ii,tt)]) ⟂ LambdaL[ll,ii,tt])

    # (G-6) Capital productivity in exogenous-productivity sectors.
    @constraint(model, G_6[ii in ink, vv in v, tt in t], (LambdaK[ii,vv,tt]) - ((1 + ChiP[ii,tt] + (1 - AlphaP[ii,tt]) * PAR[:gamma_s][(ii,tt)])^PAR[:nstep] * PAR[:lambda_k0][(ii,vv,tt)]) ⟂ LambdaK[ii,vv,tt])

    # (G-7) Land productivity in exogenous-productivity sectors.
    @constraint(model, G_7[ii in ink, tt in t], (LambdaT[ii,tt]) - ((1 + ChiP[ii,tt] + (1 - AlphaP[ii,tt]) * PAR[:gamma_s][(ii,tt)])^PAR[:nstep] * PAR[:lambda_t0][(ii,tt)]) ⟂ LambdaT[ii,tt])

    # (G-8) Sector-specific-factor productivity in exogenous-productivity sectors.
    @constraint(model, G_8[ii in ink, tt in t], (LambdaF[ii,tt]) - ((1 + ChiP[ii,tt] + (1 - AlphaP[ii,tt]) * PAR[:gamma_s][(ii,tt)])^PAR[:nstep] * PAR[:lambda_f0][(ii,tt)]) ⟂ LambdaF[ii,tt])

    # (G-9) Population update.
    @constraint(model, G_9[tt in t], (PopDyn[tt]) - ((1 + PAR[:g_pop][tt])^PAR[:nstep] * PAR[:Pop0][tt]) ⟂ PopDyn[tt])

    # (G-10) Labor-supply shift update.
    @constraint(model, G_10[tt in t], (ChiL[tt]) - ((1 + PAR[:g_L][tt])^PAR[:nstep] * PAR[:ChiL0][tt]) ⟂ ChiL[tt])

    # (G-11) Land-supply shift update.
    @constraint(model, G_11[tt in t], (ChiT[tt]) - ((1 + PAR[:g_T][tt])^PAR[:nstep] * PAR[:ChiT0][tt]) ⟂ ChiT[tt])

    # (G-12) Sector-specific-factor supply shift update.
    @constraint(model, G_12[ii in i, tt in t], (ChiF[ii,tt]) - ((1 + PAR[:g_F][(ii,tt)])^PAR[:nstep] * PAR[:ChiF0][(ii,tt)]) ⟂ ChiF[ii,tt])

    # (G-13) Installed capital at beginning of period.
    @constraint(model, G_13[ii in i], (K0[ii]) - (sum((1 - PAR[:delta])^PAR[:nstep] * Kvd[ii,vv] for vv in v)) ⟂ K0[ii])

    # (G-14) Land productivity update for non-agricultural sectors.
    @constraint(model, G_14[ii in ik, tt in t], (LambdaT[ii,tt]) - ((1 + PAR[:gamma_t][(ii,tt)])^PAR[:nstep] * PAR[:lambda_t0][(ii,tt)]) ⟂ LambdaT[ii,tt])

    # (G-15) Sector-specific-factor productivity update for non-agricultural sectors.
    @constraint(model, G_15[ii in ik, tt in t], (LambdaF[ii,tt]) - ((1 + PAR[:gamma_f][(ii,tt)])^PAR[:nstep] * PAR[:lambda_f0][(ii,tt)]) ⟂ LambdaF[ii,tt])

    # (G-16) Autonomous energy-efficiency improvement by fuel and sector.
    @constraint(model, G_16[ee in e, ii in i, tt in t], (LambdaEP[ee,ii,tt]) - ((1 + PAR[:gamma_e][(ee,ii,tt)])^PAR[:nstep] * PAR[:lambda_ep0][(ee,ii,tt)]) ⟂ LambdaEP[ee,ii,tt])

    # Note: the LINKAGE note has no equation numbered (G-17).

    # Annex G AIDADS equations. These retain the paper numbering (G-18)--(G-30).
    # (G-18) Expenditure elasticity from marginal and average budget shares.
    @constraint(model, G_18[kk in k], (EtaC[kk] * BudgetShare[kk]) - (MargBudget[kk]) ⟂ EtaC[kk])

    # (G-19) Average budget share decomposition.
    @constraint(model, G_19[kk in k], (BudgetShare[kk]) - (MuC[kk] + LambdaAIDADS * (AIDADSAlpha[kk] + AIDADSBeta[kk])) ⟂ BudgetShare[kk])

    # (G-20) Alternative budget share aggregation across commodities.
    @constraint(model, G_20[kk in k], (BudgetShare[kk]) - (MuC[kk] + sum(PAR[:delta_c][(kk,k2)] * BudgetShare[k2] for k2 in k)) ⟂ BudgetShare[kk])

    # (G-21) Slutsky substitution term.
    @constraint(model, G_21[kk in k, k2 in k], (SigmaC[kk,k2]) - (MuC[k2] - DeltaC[kk,k2]) ⟂ SigmaC[kk,k2])

    # (G-22) Symmetry-adjusted substitution term.
    @constraint(model, G_22[kk in k, k2 in k], (SigmaC[k2,kk]) - (MuC[kk] - DeltaC[k2,kk]) ⟂ SigmaC[k2,kk])

    # (G-23) Compensated price elasticity component.
    @constraint(model, G_23[kk in k, k2 in k], (XiC[kk,k2]) - (BudgetShare[k2] * SigmaC[kk,k2]) ⟂ XiC[kk,k2])

    # (G-24) Uncompensated price elasticity.
    @constraint(model, G_24[kk in k, k2 in k], (EpsC[kk,k2]) - (XiC[kk,k2] - BudgetShare[k2] * EtaC[kk]) ⟂ EpsC[kk,k2])

    # (G-25) Household budget identity over consumer goods.
    @constraint(model, G_25[hh in S[:h]], (sum(PC[kk] * XH[kk,hh] for kk in k)) - (YC[hh]) ⟂ YC[hh])

    # (G-26) AIDADS expenditure elasticity definition.
    @constraint(model, G_26[kk in k], (EtaC[kk]) - (MargBudget[kk] / (BudgetShare[kk] + 1.0e-9)) ⟂ EtaC[kk])

    # (G-27) Own-price elasticity condition.
    @constraint(model, G_27[kk in k], (EpsC[kk,kk]) - (-EtaC[kk]) ⟂ EpsC[kk,kk])

    # (G-28) Adding-up for α parameters.
    @constraint(model, G_28, (sum(AIDADSAlpha[kk] for kk in k)) - (1) ⟂ AIDADSAlpha[first(k)])

    # (G-29) Adding-up for β parameters.
    @constraint(model, G_29, (sum(AIDADSBeta[kk] for kk in k)) - (1) ⟂ AIDADSBeta[first(k)])

    # (G-30) Calibration restriction based on elasticity differences.
    @constraint(model, G_30, (LambdaAIDADS) - (sum(EpsC[kk,k2] - EpsC[k2,kk] for kk in k for k2 in k)) ⟂ LambdaAIDADS)

    return model
end
