# Usage: add_closure_equations!(model, data, PAR)
# Paper-numbered LINKAGE domestic closure equations C-1--C-12.

function add_closure_equations!(model, data::LinkageData, PAR)
    S=data.sets; default_sets!(data)
    i=S[:i]; r=S[:r]; rp=S[:rp]; h=S[:h]; f=S[:f]; l=S[:l]; v=S[:v]; ins=S[:in]

    TarY=model[:TarY]; RTarY=model[:RTarY]; YG=model[:YG]; Sg=model[:Sg]; RSg=model[:RSg]
    PGDP=model[:PGDP]; PFD=model[:PFD]; FD=model[:FD]; Sf=model[:Sf]; SAV=model[:SAV]; DeprY=model[:DeprY]
    InvSh=model[:InvSh]; WRR=model[:WRR]; PNUM=model[:PNUM]; FDInv=model[:FDInv]; GDPMPr=model[:GDPMPr]
    PP=model[:PP]; PX=model[:PX]; XP=model[:XP]; PA=model[:PA]; XAp=model[:XAp]; XAc=model[:XAc]; XAf=model[:XAf]
    WPE=model[:WPE]; WPM=model[:WPM]; WTFd=model[:WTFd]; WTFout=model[:WTFout]; WTFs=model[:WTFs]; TauPR=model[:TauPR]
    NW=model[:NW]; LV=model[:LV]; Nfirm=model[:Nfirm]; LF_d=model[:LF_d]; NPT=model[:NPT]; Td=model[:Td]
    NR=model[:NR]; Kvd=model[:Kvd]; KF_d=model[:KF_d]; YH=model[:YH]; FDInvVar=model[:FDInv]

    oldv = ("Old" in v) ? "Old" : first(v)
    gov = ("Gov" in f) ? "Gov" : first(f)
    inv = ("Inv" in f) ? "Inv" : last(f)
    rr0 = first(r)

    # (C-1) Nominal tariff revenue, including in- and over-quota imports.
    @constraint(model, C_1, (TarY) - (sum(WPM[rrp,rr,ii] * (PAR[:tau_m][(rrp,rr,ii)]*WTFd[rrp,rr,ii] + PAR[:tau_out][(rrp,rr,ii)]*WTFout[rrp,rr,ii]) for ii in i for rr in r for rrp in rp)) ⟂ TarY)

    # (C-2) Real tariff revenue.
    @constraint(model, C_2, (RTarY) - (TarY / PGDP[rr0]) ⟂ RTarY)

    # (C-3) Gross government revenues.
    @constraint(model, C_3, (YG) - (sum(PAR[:tau_p][ii] * (1 + PAR[:pi][ii]) * PX[ii] * XP[ii] for ii in i)
          + sum(PAR[:chi_kappa] * PAR[:kappa_h][hh] * YH[hh] for hh in h)
          + sum(PA[ii] * (sum(PAR[:tau_Ap][(ii,jj)]*XAp[ii,jj] for jj in i) + sum(PAR[:tau_Ac][(ii,hh)]*XAc[ii,hh] for hh in h) + sum(PAR[:tau_Af][(ii,ff)]*XAf[ii,ff] for ff in f)) for ii in i)
          + TarY
          + sum(PAR[:tau_e][(rr,rrp,ii)] * WPE[rr,rrp,ii] * WTFs[rr,rrp,ii] for ii in i for rr in r for rrp in rp)
          + sum(PAR[:tau_trq_share][(rrp,rr,ii)] * TauPR[rrp,rr,ii] * WPM[rrp,rr,ii] * WTFd[rrp,rr,ii] for ii in i for rr in r for rrp in rp)
          + sum(PAR[:tau_l][(ll,ii)] * NW[ll,ii] * (LV[ll,ii] + Nfirm[ii]*LF_d[ll,ii]) for ii in i for ll in l)
          + sum(PAR[:tau_t][ii] * NPT[ii] * Td[ii] for ii in i)
          + sum(PAR[:tau_k][(ii,vv)] * NR[ii,vv] * Kvd[ii,vv] for ii in i for vv in v)
          + sum(PAR[:tau_k][(ii,oldv)] * NR[ii,oldv] * Nfirm[ii] * KF_d[ii] for ii in i)) ⟂ YG)

    # (C-4) Government saving / net fiscal position.
    @constraint(model, C_4, (Sg) - (YG - PFD[gov]*FD[gov] - sum(PGDP[rr0]*PAR[:TRG][hh] for hh in h)
             + PNUM*sum(PAR[:WTRgov_in][(rrp,inn)] for rrp in rp for inn in ins)
             - PNUM*sum(PAR[:WTRgov_out][(rrp,inn)] for rrp in rp for inn in ins)) ⟂ Sg)

    # (C-5) Real government saving.
    @constraint(model, C_5, (RSg) - (Sg / PGDP[rr0]) ⟂ RSg)

    # (C-6) Government expenditure volume as share of real GDP at market prices.
    @constraint(model, C_6, (FD[gov]) - (PAR[:chi_gov] * GDPMPr) ⟂ FD[gov])

    # (C-7) Foreign saving value at world numeraire price.
    @constraint(model, C_7[rr in r], (Sf[rr]) - (PNUM * PAR[:Sfbar][rr]) ⟂ Sf[rr])

    # (C-8) World foreign saving sums to zero.
    @constraint(model, C_8, (sum(Sf[rr] for rr in r)) - (0) ⟂ Sf[first(r)])

    # (C-9) Savings-investment balance; one region normally dropped by Walras law.
    @constraint(model, C_9, (PFD[inv]*FD[inv]) - (sum(SAV[hh] + DeprY[hh] for hh in h) + Sg + Sf[rr0]
        + PNUM*sum(PAR[:WTRinv_in][(rrp,inn)] for rrp in rp for inn in ins)
        - PNUM*sum(PAR[:WTRinv_out][(rrp,inn)] for rrp in rp for inn in ins)) ⟂ FD[inv])

    # (C-10) Investment share of GDP at market prices.
    @constraint(model, C_10, (InvSh) - (PFD[inv] * FD[inv] / GDPMPr) ⟂ InvSh)

    # (C-11) World numeraire price index of OECD manufacturing exports.
    @constraint(model, C_11, (PNUM) - (sum(WPE[rr,rrp,ii] * PAR[:WTF0][(rr,rrp,ii)] for rr in r for rrp in rp for ii in i) /
                sum(PAR[:WPE0][(rr,rrp,ii)] * PAR[:WTF0][(rr,rrp,ii)] for rr in r for rrp in rp for ii in i)) ⟂ PNUM)

    # (C-12) World average rate of return to capital.
    @constraint(model, C_12, (WRR) - (sum(PAR[:TR_region][rr] * PAR[:K_region][rr] for rr in r) / sum(PAR[:K_region][rr] for rr in r)) ⟂ WRR)

    return model
end
