# MCP/PATH conversion notes

This version removes the NLP objective function and uses Complementarity.jl with the PATH solver.

Main changes:

- `Project.toml` now depends on `Complementarity` and `PATHSolver`.
- `src/Objective.jl` was removed from the build.
- `build_model` now constructs `MCPModel()`.
- `solve_model!` calls `solveMCP(...; solver=:PATH)`.
- Equation files now use `@mapping` and `@complementarity` instead of optimization constraints.
- Equality equations are represented with free auxiliary complementarity variables, which enforces the mapping residual to zero.
- Inequality equations are represented with nonnegative auxiliary complementarity variables, which enforces the mapped inequality residual to be nonnegative.

Typical usage:

```julia
include("src/LinkageModel.jl")
using .LinkageModel

data = prepare_data!()
m = model(data)
status = solve_model!(m)
println(status)
export_results!(m, data)
```
