# MCP Constraint Rewrite

The MCP equations have been rewritten to use direct Complementarity.jl/JuMP constraint syntax:

```julia
@constraint(model, EqName[index_set], residual_expression ⟂ lhs_variable)
```

The previous `@mapping` and `@complementarity` macro pairs were removed. No artificial MCP residual variables are created.

For example:

```julia
@constraint(model, P_1[ii in i],
    (ND[ii]) -
    (PAR[:AT][ii] * sum(PAR[:alpha_nd][(ii,vv)] * XPv[ii,vv] *
    (UVCv[ii,vv] / PND[ii])^(PAR[:sigma_p][(ii,vv)]) for vv in v)) ⟂ ND[ii])
```
