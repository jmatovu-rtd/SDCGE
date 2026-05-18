# Usage: add_equilibrium_equations!(model, data, PAR)
# Paper-numbered LINKAGE goods-market equilibrium equations.

function add_equilibrium_equations!(model, data::LinkageData, PAR)
    S=data.sets; default_sets!(data)
    i=S[:i]; r=S[:r]; rp=S[:rp]
    XDs=model[:XDs]; XDd=model[:XDd]; WTFd=model[:WTFd]; WTFs=model[:WTFs]

    # (E-1) Domestic market equilibrium: local supply equals local demand.
    @constraint(model, E_1[ii in i], (XDs[ii]) - (XDd[ii]) ⟂ XDs[ii])

    # (E-2) World trade-flow equilibrium with iceberg trade friction.
    @constraint(model, E_2[rr in r, rrp in rp, ii in i], (WTFd[rr,rrp,ii]) - (PAR[:lambda_w][(rr,rrp,ii)] * WTFs[rr,rrp,ii]) ⟂ WTFd[rr,rrp,ii])

    return model
end
