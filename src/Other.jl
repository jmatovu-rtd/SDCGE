# Usage: add_other_equations!(model, data, PAR)
# Paper-numbered LINKAGE equations coded as JuMP constraints.

function add_other_equations!(model, data::LinkageData, PAR)
    S=data.sets; default_sets!(data)
    i=S[:i]; j=S[:j]; k=S[:k]; r=S[:r]; rp=S[:rp]; v=S[:v]; l=S[:l]; h=S[:h]; f=S[:f]; ins=S[:in]; t=S[:t]
    cr=S[:cr]; lv=S[:lv]; ip=S[:ip]; e=S[:e]; ft=S[:ft]; fd=S[:fd]; nf=S[:nf]; nnft=S[:nnft]; nnfd=S[:nnfd]; gz=S[:gz]

    GDP=model[:GDP]; RGDP=model[:RGDP]; CPI=model[:CPI]; PGDP=model[:PGDP]; PNUM=model[:PNUM]; XP=model[:XP]; PP=model[:PP]; XQ=model[:XQ]; PC=model[:PC]
    @constraint(model, M_1[rr in r], (GDP[rr]) - (sum(PP[ii]*XP[ii] for ii in i)) ⟂ GDP[rr])
    @constraint(model, M_2[rr in r], (RGDP[rr]) - (sum(XP[ii] for ii in i)) ⟂ RGDP[rr])
    @constraint(model, M_3[rr in r], (PGDP[rr]*RGDP[rr]) - (GDP[rr]) ⟂ PGDP[rr])
    @constraint(model, M_4[rr in r], (CPI[rr]) - (sum(PC[kk] for kk in k)/length(k)) ⟂ CPI[rr])
    @constraint(model, M_5, (PNUM) - (1.0) ⟂ PNUM)

    return model
end
