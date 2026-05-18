# LINKAGE 100-sector JuMP package

This version restores paper-numbered equation coverage from the uploaded LINKAGE Technical Reference Document.

Main entry points:

```julia
include("src/LinkageModel.jl")
using .LinkageModel

data = init_data()
prepare_data!(data)
m = model(data)
solve_model!(m)
```

Equation blocks are in `src/Production.jl`, `src/Income.jl`, `src/Demand.jl`, `src/Trade.jl`, `src/Equilibrium.jl`, `src/Closure.jl`, `src/Factors.jl`, `src/Other.jl`, `src/Dynamics.jl`, and `src/Accounting.jl`.

Audits:
- `docs/equation_coverage_complete.csv`
- `docs/variable_declaration_audit_complete.csv`

Notes:
- No non-paper equation labels are present.
- Paper equation (G-17) is not present in the note and is not generated.
- Factor-market regime cases are represented through explicit JuMP constraints using the paper-numbered equations.


Update in this revision:
- Added `src/Functions.jl` with reusable CES, CET, calibration, and long-run Armington-share formulas from Annex C and Annex D (PDF pp. 70--75).
- Production nests still keep explicit paper-numbered JuMP constraints, but calibration/validation can now call the same functional forms directly.
