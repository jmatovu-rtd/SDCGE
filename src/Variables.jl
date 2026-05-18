# Usage:
#   add_variables!(model, data)
# All endogenous variables are declared in this single JuMP macro.

function add_variables!(model, data::LinkageData)
    S=data.sets; default_sets!(data)
    i=S[:i]; j=S[:j]; k=S[:k]; r=S[:r]; rp=S[:rp]; v=S[:v]; l=S[:l]; h=S[:h]; f=S[:f]; ins=S[:in]; t=S[:t]; gz=S[:gz]; e=S[:e]

    # Starting values are computed from the balanced SAM/data and applied immediately
    # after variable declarations with initialize_from_sam!(model, data).

    @variables(model, begin
        XPv[i,v] >= 0
        XP[i] >= 0
        ND[i] >= 0
        VA[i,v] >= 0
        PND[i] >= 0
        PVA[i,v] >= 0
        UVCv[i,v] >= 0
        UVC[i] >= 0
        AC[i] >= 0
        Nfirm[i] >= 0
        PX[i] >= 0
        PP[i] >= 0
        PROFIT[i] >= 0
        ULD[i] >= 0
        SLD[i] >= 0
        HKTEF[i,v] >= 0
        PHKTEF[i,v] >= 0
        fert[i] >= 0
        Pfert[i] >= 0
        HKTE[i,v] >= 0
        PHKTE[i,v] >= 0
        XEp[i,v] >= 0
        PEp[i,v] >= 0
        HKT[i,v] >= 0
        PHKT[i,v] >= 0
        KT[i,v] >= 0
        PKT[i,v] >= 0
        Kvd[i,v] >= 0
        Td[i] >= 0
        Fd[i] >= 0
        XAp[j,i] >= 0
        PA[i] >= 0
        PAp[j,i] >= 0
        XDp[j,i] >= 0
        XMp[j,i] >= 0
        Pfeed[i] >= 0
        feed[i] >= 0
        KTEL[i,v] >= 0
        PKTEL[i,v] >= 0
        TFD[i,v] >= 0
        PTFD[i,v] >= 0
        LV[l,i] >= 0
        W[l,i] >= 0
        UW[i] >= 0
        SW[i] >= 0
        LF_d[l,i] >= 0
        KF_d[i] >= 0
        PT[i] >= 0
        NPT[i] >= 0
        PF[i] >= 0
        R[i,v] >= 0
        NR[i,v] >= 0
        TY >= 0
        FY >= 0
        LY[l] >= 0
        KY >= 0
        YH[h] >= 0
        DeprY[h] >= 0
        YD[h] >= 0
        YC[h] >= 0
        XH[k,h] >= 0
        PC[k] >= 0
        PQ[k] >= 0
        SAV[h] >= 0
        GOVDEM[i] >= 0
        INVDEM[i] >= 0
        XA[i] >= 0
        XD[i] >= 0
        XM[i] >= 0
        PMT[i] >= 0
        PD[i] >= 0
        PM[r,rp,i] >= 0
        XMT[i] >= 0
        XW[i,r,rp] >= 0
        PWM[i,r,rp] >= 0
        PWE[i,r,rp] >= 0
        PE[r,rp,i] >= 0
        PET[i] >= 0
        E[i] >= 0
        D[i] >= 0
        TAXREV >= 0
        MTAXREV >= 0
        RMTAXREV >= 0
        GOVREV >= 0
        GEXP >= 0
        GDEF
        SAVE
        INVEST >= 0
        CA[r]
        GDP[r] >= 0
        RGDP[r] >= 0
        CPI[r] >= 0
        PGDP[r] >= 0
        WALRAS
        # Exogenous supplies are NOT JuMP variables.
        # They are calibrated/provided through data.par and precomputed into PAR:
        #   PAR[:KSupply][(i,v)], PAR[:LSupply][l], PAR[:TSupply][i], PAR[:FSupply][i]
        MIG[l,r,rp] >= 0
        UNEMP[l,r] >= 0
        KStock[i,v] >= 0
        INVK[i,v] >= 0
        QINV[i] >= 0
        TFP[i] >= 0
        OPEN[i] >= 0
        POP[r] >= 0
        AEEI[i] >= 0
        GDPPC[r] >= 0
        XQ[i] >= 0
        PNUM >= 0

        # Labor market variables from LINKAGE factor-market equations (F-1)--(F-12)
        LS[l,gz] >= 0
        MIGR[l]
        AVGW[l,gz] >= 0
        NW[l,i] >= 0
        TW[l,gz] >= 0
        WMIN[l,gz] >= 0
        UE[l,gz] >= 0
        PS[gz] >= 0
        PABS >= 0
        # Land, natural resource, and capital-market variables (F-13)--(F-33)
        TLnd >= 0
        PTLnd >= 0
        Ts[i] >= 0
        Fs[i] >= 0
        KSs[i] >= 0
        KS >= 0
        TR >= 0
        RR[i] >= 0
        CHIv[i,v] >= 0
        K0[i] >= 0
        FDInv >= 0
        KActual >= 0
        GammaInv
        KNorm >= 0
        # Dynamic productivity and AIDADS variables (G-1)--(G-30)
        RGDPMP[t] >= 0
        LambdaL[l,i,t] >= 0
        LambdaK[i,v,t] >= 0
        LambdaT[i,t] >= 0
        LambdaF[i,t] >= 0
        LambdaEP[e,i,t] >= 0
        ChiP[i,t]
        AlphaP[i,t]
        EtaP[i]
        PhiP[i,t]
        PopDyn[t] >= 0
        ChiL[t] >= 0
        ChiT[t] >= 0
        ChiF[i,t] >= 0
        EtaC[k]
        BudgetShare[k] >= 0
        MuC[k]
        AIDADSAlpha[k]
        AIDADSBeta[k]
        MargBudget[k]
        SigmaC[k,k]
        DeltaC[k,k]
        XiC[k,k]
        EpsC[k,k]
        LambdaAIDADS >= 0
        # accounting / data variables from Annex H
        VDFM[i,j] >= 0
        VDFA[i,j] >= 0
        VIFM[i,j] >= 0
        VIFA[i,j] >= 0
        EVFA[l,i] >= 0
        XDc[i] >= 0
        XMc[i] >= 0
        CDTax[i] >= 0
        CMTax[i] >= 0
        XDf[i,f] >= 0
        XMf[i,f] >= 0
        FDTax[i,f] >= 0
        FMTax[i,f] >= 0
        WTOUT[r] >= 0
        XMgr[i] >= 0
        AXMg[r] >= 0
        APMg[r] >= 0

        # Paper-exact demand variables (D-1)--(D-14)
        YSTAR[h] >= 0
        CPIH[h] >= 0
        XAc[i,h] >= 0
        PAc[i,h] >= 0
        XAf[i,f] >= 0
        PFD[f] >= 0
        FD[f] >= 0
        XDd[i] >= 0
        XDs[i] >= 0
        XMTd[i] >= 0
        XM1[r,i] >= 0
        PM1[r,i] >= 0
        XM2[r,i] >= 0
        PM2[r,i] >= 0
        WTFd[r,rp,i] >= 0
        WTFs[r,rp,i] >= 0
        WTFin[r,rp,i] >= 0
        WTFout[r,rp,i] >= 0
        WTFq[r,rp,i] >= 0
        TauPR[r,rp,i] >= 0
        ES[i] >= 0
        WPE[r,rp,i] >= 0
        WPM[r,rp,i] >= 0
        WXMg >= 0
        WPMg >= 0
        TarY >= 0
        RTarY >= 0
        YG >= 0
        Sg
        RSg
        Sf[r]
        InvSh >= 0
        WRR >= 0
        # AIDS alternative trade specification variables (T-28)--(T-34)
        AIDSSH[r,rp,i]
        PMa[r,rp,i] >= 0
        XDM[r,i] >= 0
        PDM[r,i] >= 0
        GDPMPr >= 0
    end)

    # Second-pass safeguard: applies the same SAM/data starts with set_start_value.
    # This keeps compatibility with solvers/JuMP versions that ignore declaration starts.
    initialize_from_sam!(model, data)

    return model
end
