# Usage: add_accounting_equations!(model, data, PAR)
# Annex H accounting bridge equations.
#
# These constraints link the main LINKAGE equilibrium variables to the GTAP-style
# value-flow variables (VDFM, VDFA, VIFM, VIFA, EVFA) and to aggregate accounting
# identities (TAXREV, GOVREV, SAVE, INVEST, GDP, CA).
#
# IMPORTANT — several constraints below are stubs/placeholders that pin variables to
# zero or to a single-agent approximation.  They are marked "(stub)" and should be
# replaced with full multi-agent accounting when real data and institutional detail
# become available.  The stubs keep PATH from treating those variables as free.

function add_accounting_equations!(model, data::LinkageData, PAR)
    S=data.sets; default_sets!(data)
    i=S[:i]; j=S[:j]; k=S[:k]; r=S[:r]; rp=S[:rp]; v=S[:v]; l=S[:l]; h=S[:h]; f=S[:f]; ins=S[:in]; t=S[:t]
    cr=S[:cr]; lv=S[:lv]; ip=S[:ip]; e=S[:e]; ft=S[:ft]; fd=S[:fd]; nf=S[:nf]; nnft=S[:nnft]; nnfd=S[:nnfd]; gz=S[:gz]

    VDFM=model[:VDFM]; VDFA=model[:VDFA]; VIFM=model[:VIFM]; VIFA=model[:VIFA]
    XDp=model[:XDp]; XMp=model[:XMp]; XAp=model[:XAp]; PAp=model[:PAp]
    EVFA=model[:EVFA]; XDc=model[:XDc]; XMc=model[:XMc]
    CDTax=model[:CDTax]; CMTax=model[:CMTax]
    XDf=model[:XDf]; XMf=model[:XMf]; FDTax=model[:FDTax]; FMTax=model[:FMTax]
    Td=model[:Td]; LV=model[:LV]; Kvd=model[:Kvd]; Fd=model[:Fd]
    XH=model[:XH]; XM=model[:XM]; GOVDEM=model[:GOVDEM]; INVDEM=model[:INVDEM]
    XA=model[:XA]; TAXREV=model[:TAXREV]; XP=model[:XP]
    YH=model[:YH]; W=model[:W]; GOVREV=model[:GOVREV]
    SAVE=model[:SAVE]; SAV=model[:SAV]; INVEST=model[:INVEST]
    CA=model[:CA]; GDP=model[:GDP]; PP=model[:PP]; RGDP=model[:RGDP]
    @constraint(model, H_1[ii in i, jj in j], (XDp[ii,jj]) - (VDFM[ii,jj]) ⟂ XDp[ii,jj])
    @constraint(model, H_2[ii in i, jj in j], (PAp[ii,jj]) - (VDFA[ii,jj] - VDFM[ii,jj]) ⟂ PAp[ii,jj])
    @constraint(model, H_3[ii in i, jj in j], (XMp[ii,jj]) - (VIFM[ii,jj]) ⟂ XMp[ii,jj])
    @constraint(model, H_4[ii in i, jj in j], (PAp[ii,jj]) - (VIFA[ii,jj] - VIFM[ii,jj]) ⟂ PAp[ii,jj])
    @constraint(model, H_5[ii in i], (Td[ii]) - (EVFA[first(l),ii]) ⟂ Td[ii])
    @constraint(model, H_6[ii in i], (LV["UnSkLab",ii]) - (EVFA["UnSkLab",ii]) ⟂ LV["UnSkLab",ii])
    @constraint(model, H_7[ii in i], (LV["SkLab",ii]) - (EVFA["SkLab",ii]) ⟂ LV["SkLab",ii])
    @constraint(model, H_8[ii in i], (sum(Kvd[ii,vv] for vv in v)) - (EVFA[first(l),ii]) ⟂ Kvd[ii,first(v)])
    @constraint(model, H_9[ii in i], (Fd[ii]) - (EVFA[first(l),ii]) ⟂ Fd[ii])
    @constraint(model, H_10[ii in i], (XDc[ii]) - (XH[ii,first(h)]) ⟂ XDc[ii])
    @constraint(model, H_11[ii in i], (CDTax[ii]) - (0) ⟂ CDTax[ii])
    @constraint(model, H_12[ii in i], (XMc[ii]) - (XM[ii]) ⟂ XMc[ii])
    @constraint(model, H_13[ii in i], (CMTax[ii]) - (0) ⟂ CMTax[ii])
    @constraint(model, H_14[ii in i], (XDf[ii,"Gov"]) - (GOVDEM[ii]) ⟂ XDf[ii,"Gov"])
    @constraint(model, H_15[ii in i], (FDTax[ii,"Gov"]) - (0) ⟂ FDTax[ii,"Gov"])
    @constraint(model, H_16[ii in i], (XMf[ii,"Gov"]) - (GOVDEM[ii]) ⟂ XMf[ii,"Gov"])
    @constraint(model, H_17[ii in i], (FMTax[ii,"Gov"]) - (0) ⟂ FMTax[ii,"Gov"])
    @constraint(model, H_18[ii in i], (XDf[ii,"Inv"]) - (INVDEM[ii]) ⟂ XDf[ii,"Inv"])
    @constraint(model, H_19[ii in i], (FDTax[ii,"Inv"]) - (0) ⟂ FDTax[ii,"Inv"])
    @constraint(model, H_20[ii in i], (XMf[ii,"Inv"]) - (INVDEM[ii]) ⟂ XMf[ii,"Inv"])
    @constraint(model, H_21[ii in i], (FMTax[ii,"Inv"]) - (0) ⟂ FMTax[ii,"Inv"])
    @constraint(model, H_22[ii in i, jj in j], (XAp[ii,jj]) - (XDp[ii,jj] + XMp[ii,jj]) ⟂ XAp[ii,jj])
    @constraint(model, H_23[ii in i, jj in j], (PAp[ii,jj]) - (0) ⟂ PAp[ii,jj])
    @constraint(model, H_24[ii in i], (XA[ii]) - (XDc[ii] + XMc[ii]) ⟂ XA[ii])
    @constraint(model, H_25[ii in i], (TAXREV) - (CDTax[ii] + CMTax[ii]) ⟂ TAXREV)
    @constraint(model, H_26[ii in i], (TAXREV) - (sum(FDTax[ii,ff] + FMTax[ii,ff] for ff in f)) ⟂ TAXREV)
    @constraint(model, H_27[ii in i], (XP[ii]) - (sum(XDp[ii,jj] for jj in j)) ⟂ XP[ii])
    @constraint(model, H_28[ii in i], (XM[ii]) - (sum(XMp[ii,jj] for jj in j)) ⟂ XM[ii])
    @constraint(model, H_29[ii in i], (YH[first(h)]) - (sum(W[ll,ii]*LV[ll,ii] for ll in l)) ⟂ YH[first(h)])
    @constraint(model, H_30[ii in i], (GOVREV) - (TAXREV) ⟂ GOVREV)
    @constraint(model, H_31[ii in i], (SAVE) - (SAV[first(h)]) ⟂ SAVE)
    @constraint(model, H_32[ii in i], (INVEST) - (INVDEM[ii]) ⟂ INVEST)
    @constraint(model, H_33[ii in i], (CA[first(r)]) - (CA[first(r)]) ⟂ CA[first(r)])
    @constraint(model, H_34[ii in i], (GDP[first(r)]) - (PP[ii]*XP[ii]) ⟂ GDP[first(r)])
    @constraint(model, H_35[ii in i], (RGDP[first(r)]) - (XP[ii]) ⟂ RGDP[first(r)])

    return model
end
