# Equation correction notes

This package was regenerated after a label-by-label audit against the LINKAGE Technical Reference Document.

Main corrections relative to previous package:

- `Y-3` and `Y-4` now match the paper's labor and capital income equations, including fixed-cost labor/capital and profits.
- `D-1`--`D-9` now follow the final-demand section exactly: supernumerary income, ELES demand, saving residual, CPI, transition matrix, CES consumer-price dual, household Armington price, fixed-coefficient other final demand, and PFD.
- `D-10`--`D-14` are retained as the paper's agent-specific Armington equations from the alternative specification block.
- `T-1`--`T-27` were rewritten according to the paper's Armington/CET/trade-price/trade-margin system.
- `T-28`--`T-34` are coded as the paper's AIDS/alternative trade specification rather than placeholder non-negativity constraints.
- `E-1` and `E-2` now match domestic goods-market and bilateral trade-flow equilibrium.
- `C-1`--`C-12` now follow the closure equations: tariff revenue, real tariff revenue, gross government revenue, government saving, real government saving, government demand, foreign saving, global foreign-saving balance, savings-investment balance, investment share, numeraire, and world rate of return.

See `docs/equation_audit_corrected.csv` for paper-label coverage.


## Production-function helper update
- Added `src/Functions.jl` implementing Annex C CES demand/dual price/calibration, Leontief and Cobb-Douglas special cases, CET supply/dual price/share mapping, and Annex D long-run Armington share updates from pp. 70--75.
- These functions complement the explicit production constraints in `src/Production.jl` and reduce the risk of inconsistent CES/CET formulas across production, trade, and calibration code.


## Labor demand correction

Restored the production labor-demand disaggregation equations P-72--P-75 from the LINKAGE technical note. These now map aggregate ULD and SLD bundles to skill-specific labor demand `LV[l,i]`, with dual wage-price equations for `UW[i]` and `SW[i]`. The earlier placeholder constraints using P-72--P-75 numbering were moved out of the paper-numbered sequence.

## Conditional equation branches fixed

The model now handles paper-level `if` statements at equation-construction time instead of imposing all branches simultaneously.

Updated factor-market branches:

- **F-5 migration**: active only for segmented labor markets (`omega_migr` finite). For integrated markets (`omega_migr == Inf`), migration is fixed at zero.
- **F-6 national wage condition**: integrated markets use the MCP product form `(TW - WMIN) * UE = 0`; segmented markets set national `TW` equal to `AVGW` for accounting only.
- **F-7 regional wage condition**: segmented markets use the regional MCP product form; integrated markets set regional wages equal to the national wage.
- **F-8 national minimum wage**: active only for integrated markets.
- **F-9 regional minimum wage**: segmented markets use the regional formula; integrated markets inherit the national minimum wage.

These changes correspond to the conditional equations and discussion in the labor-market section of the LINKAGE technical note.


## Explicit if-conditions inside equations

Revised the factor-market equations so the paper's conditional regimes are no longer only described in comments or precomputed sets. The conditions are now embedded directly in the JuMP equation index filters:

- `F_5[ll in l; !isinf(PAR[:omega_migr][ll])]` applies migration only for segmented labor markets.
- `F_5_if_integrated[ll in l; isinf(PAR[:omega_migr][ll])]` fixes migration to zero for integrated markets.
- `F_6_if_integrated` / `F_6_if_segmented`, `F_7_if_integrated` / `F_7_if_segmented`, `F_8_if_integrated`, and `F_9_if_integrated` / `F_9_if_segmented` now carry the same explicit `if` conditions in their equation definitions.

This makes the conditional structure visible where the equations are declared, rather than hiding it in helper sets.


## Ternary operator form for paper if-conditions

Replaced the split branch equations for `F-5`--`F-9` with single ternary-style equations using Julia's `condition ? value_if_true : value_if_false` syntax. Each paper if-condition is now embedded directly in the equation body, for example integrated labor markets use the national wage/minimum-wage branch, while segmented markets use the regional/migration branch.

## F-13--F-25 ternary-condition correction

Updated `src/Factors.jl` so F-13 through F-25 preserve the full equations and their conditional branches inline using ternary-style expressions:

- F-13 now includes all three land-supply branches: constant-elasticity land supply, logistic land supply, and infinite-supply-elasticity fixed real land-price branch.
- F-14 now switches between the CET aggregate land-price equation and the perfectly-mobile-land aggregate market-clearing condition.
- F-15 now switches between sectoral land allocation and the law-of-one-price condition.
- F-18 now switches between the sector-specific factor supply function and the infinite-elasticity fixed real factor-price condition.
- F-20 now switches between single-vintage capital CET allocation and the perfect-mobility law-of-one-price condition.
- F-21 now switches between the CET aggregate capital-return equation and the perfect-mobility aggregate capital-market closure.
- F-24 now explicitly includes both parts of the paper equation: the old-capital supply inequality and the `RR <= 1` bound.
- F-22, F-23, and F-25 are retained as full equilibrium/accounting equations; they do not have separate branch-specific right-hand sides in the paper, but their surrounding conditional interpretation is documented in-line.

Julia was not available in the execution environment, so the package build script could not be run here.
