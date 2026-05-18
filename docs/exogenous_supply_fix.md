# Exogenous factor supply fix

`KSupply`, `LSupply`, `TSupply`, and `FSupply` are no longer JuMP variables.
They are exogenous model data calibrated from the balanced SAM and stored in `data.par`, then precomputed into `PAR` before JuMP constraints are created.

Parameter keys:

- `data.par[:KSupply][(i,v)]`
- `data.par[:LSupply][l]`
- `data.par[:TSupply][i]`
- `data.par[:FSupply][i]`

JuMP equations now reference:

- `PAR[:KSupply][(ii,vv)]`
- `PAR[:LSupply][ll]`
- `PAR[:TSupply][ii]`
- `PAR[:FSupply][ii]`

This fixes `UndefVarError: KSupply not defined in Main` and avoids treating exogenous supplies as endogenous variables.
