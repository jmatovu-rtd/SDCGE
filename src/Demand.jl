# Usage: add_demand_equations!(model, data, PAR)
# Exact paper-numbered LINKAGE final-demand equations.
# D-1--D-9 are the main LINKAGE final-demand block.
# D-10--D-14 implement the paper's agent-specific Armington breakout formulas from the annex,
# retained with their original numbering.

function add_demand_equations!(model, data::LinkageData, PAR)
    S=data.sets; default_sets!(data)
    i=S[:i]; j=S[:j]; k=S[:k]; h=S[:h]; f=S[:f]

    YSTAR=model[:YSTAR]; YC=model[:YC]; PC=model[:PC]; XH=model[:XH]; SAV=model[:SAV]; CPIH=model[:CPIH]
    XAc=model[:XAc]; PAc=model[:PAc]; PA=model[:PA]; XAf=model[:XAf]; FD=model[:FD]; PFD=model[:PFD]
    XDc=model[:XDc]; XMc=model[:XMc]; XDf=model[:XDf]; XMf=model[:XMf]; PD=model[:PD]; PMT=model[:PMT]

    # (D-1) Supernumerary household income: Y* = Yhc - Σ PC_k,h Pop_h θ_k,h.
    @constraint(model, D_1[hh in h], (YSTAR[hh]) - (YC[hh] - sum(PC[kk] * PAR[:PopH][hh] * PAR[:theta][(kk,hh)] for kk in k)) ⟂ YSTAR[hh])

    # (D-2) ELES household demand: XC_k,h = Pop_h θ_k,h + μ_k,h Y*_h / PC_k,h.
    @constraint(model, D_2[kk in k, hh in h], (XH[kk,hh]) - (PAR[:PopH][hh] * PAR[:theta][(kk,hh)] + PAR[:mu_c][(kk,hh)] * YSTAR[hh] / PC[kk]) ⟂ XH[kk,hh])

    # (D-3) Household saving residual: S_h = Yhc_h - Σ PC_k,h XC_k,h.
    @constraint(model, D_3[hh in h], (SAV[hh]) - (YC[hh] - sum(PC[kk] * XH[kk,hh] for kk in k)) ⟂ SAV[hh])

    # (D-4) Consumer price index at current bundle: CPI_h = Σ PC_k,h XC_k,h / Σ PC_0,k,h XC_k,h.
    @constraint(model, D_4[hh in h], (CPIH[hh]) - (sum(PC[kk] * XH[kk,hh] for kk in k) /
                    sum(PAR[:PC0][(kk,hh)] * XH[kk,hh] for kk in k)) ⟂ CPIH[hh])

    # (D-5) Transition demand for produced Armington goods used in consumption bundles.
    @constraint(model, D_5[ii in i, hh in h], (XAc[ii,hh]) - (sum(PAR[:GammaC][(ii,kk,hh)] * (PC[kk] / PAc[ii,hh])^PAR[:sigma_c][(kk,hh)] * XH[kk,hh] for kk in k)) ⟂ XAc[ii,hh])

    # (D-6) Consumer-good CES dual price.
    @constraint(model, D_6[kk in k, hh in h], (PC[kk]) - ((sum(PAR[:GammaC][(ii,kk,hh)] * PAc[ii,hh]^(1-PAR[:sigma_c][(kk,hh)]) for ii in i))^(1/(1-PAR[:sigma_c][(kk,hh)]))) ⟂ PC[kk])

    # (D-7) Household Armington purchase price with consumption sales tax.
    @constraint(model, D_7[ii in i, hh in h], (PAc[ii,hh]) - ((1 + PAR[:tau_Ac][(ii,hh)]) * PA[ii]) ⟂ PAc[ii,hh])

    # (D-8) Other final demand fixed-coefficient quantity.
    @constraint(model, D_8[ii in i, ff in f], (XAf[ii,ff]) - (PAR[:a_f][(ii,ff)] * FD[ff]) ⟂ XAf[ii,ff])

    # (D-9) Other final demand price index.
    @constraint(model, D_9[ff in f], (PFD[ff]) - (sum(PAR[:a_f][(ii,ff)] * (1 + PAR[:tau_Af][(ii,ff)]) * PA[ii] for ii in i)) ⟂ PFD[ff])

    # (D-10) Agent-specific Armington domestic household component (annex alternative specification).
    @constraint(model, D_10[ii in i, hh in h], (XDc[ii]) - (PAR[:alpha_dc][(ii,hh)] * (PAc[ii,hh] / ((1 + PAR[:tau_Dc][(ii,hh)]) * PD[ii]))^PAR[:sigma_mc][(ii,hh)] * XAc[ii,hh]) ⟂ XDc[ii])

    # (D-11) Agent-specific Armington import household component (annex alternative specification).
    @constraint(model, D_11[ii in i, hh in h], (XMc[ii]) - (PAR[:alpha_mc][(ii,hh)] * (PAc[ii,hh] / ((1 + PAR[:tau_Mc][(ii,hh)]) * PMT[ii]))^PAR[:sigma_mc][(ii,hh)] * XAc[ii,hh]) ⟂ XMc[ii])

    # (D-12) Agent-specific Armington domestic other-final-demand component.
    @constraint(model, D_12[ii in i, ff in f], (XDf[ii,ff]) - (PAR[:alpha_df][(ii,ff)] * (((1 + PAR[:tau_Af][(ii,ff)]) * PA[ii]) / ((1 + PAR[:tau_Df][(ii,ff)]) * PD[ii]))^PAR[:sigma_mf][(ii,ff)] * XAf[ii,ff]) ⟂ XDf[ii,ff])

    # (D-13) Agent-specific Armington import other-final-demand component.
    @constraint(model, D_13[ii in i, ff in f], (XMf[ii,ff]) - (PAR[:alpha_mf][(ii,ff)] * (((1 + PAR[:tau_Af][(ii,ff)]) * PA[ii]) / ((1 + PAR[:tau_Mf][(ii,ff)]) * PMT[ii]))^PAR[:sigma_mf][(ii,ff)] * XAf[ii,ff]) ⟂ XMf[ii,ff])

    # (D-14) Agent-specific Armington other-final-demand dual price.
    @constraint(model, D_14[ii in i, ff in f], ((1 + PAR[:tau_Af][(ii,ff)]) * PA[ii]) - ((PAR[:alpha_df][(ii,ff)]*((1 + PAR[:tau_Df][(ii,ff)])*PD[ii])^(1-PAR[:sigma_mf][(ii,ff)]) +
         PAR[:alpha_mf][(ii,ff)]*((1 + PAR[:tau_Mf][(ii,ff)])*PMT[ii])^(1-PAR[:sigma_mf][(ii,ff)]))^(1/(1-PAR[:sigma_mf][(ii,ff)]))) ⟂ PA[ii])

    return model
end
