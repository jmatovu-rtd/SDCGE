# Usage: add_equilibrium_equations!(model, data, PAR)
# Paper-numbered LINKAGE goods-market equilibrium equations.
#
# E_2 fix: complementary variable changed from WTFd to PE (bilateral export
# price).  T_9 in Trade.jl already defines WTFd via Armington demand.  The
# trade-balance condition (WTFd = lambda * WTFs) should instead determine the
# equilibrium bilateral export price PE that clears each origin-destination
# market.

function add_equilibrium_equations!(model, data::LinkageData, PAR)
    S=data.sets; default_sets!(data)
    i=S[:i]; r=S[:r]; rp=S[:rp]
    XDs=model[:XDs]; XDd=model[:XDd]; PD=model[:PD]
    WTFd=model[:WTFd]; WTFs=model[:WTFs]; PE=model[:PE]

    # (E-1) Domestic market equilibrium: supply equals demand; domestic price PD clears market.
    # Changed ⟂ variable from XDs to PD: T_14 already defines XDs via CET supply allocation.
    @constraint(model, E_1[ii in i], (XDs[ii]) - (XDd[ii]) ⟂ PD[ii])

    # (E-2) Bilateral trade-flow balance: imports (demand side) equal exports
    # adjusted for iceberg transport loss.  The equilibrium bilateral export
    # price PE[rr,rrp,ii] adjusts to clear each bilateral market.
    @constraint(model, E_2[rr in r, rrp in rp, ii in i],
        (WTFd[rr,rrp,ii]) - (PAR[:lambda_w][(rr,rrp,ii)] * WTFs[rr,rrp,ii]) ⟂ PE[rr,rrp,ii])

    return model
end
