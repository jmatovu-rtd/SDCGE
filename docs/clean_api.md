# Clean LINKAGE API

Use these public functions from `LinkageModel`:

```julia
include("src/LinkageModel.jl")
using .LinkageModel
```

## One-call build

```julia
m, data = run_linkage!(solve=false)
```

Set `solve=true` to optimize with PATH.

## Standard explicit workflow

```julia
data = prepare_data!()
m = model(data)
solve_model!(m)
```

## Advanced manual workflow

```julia
using JuMP, Complementarity

data = prepare_data!()
m = Model(MCPModel())
build_linkage_model!(m, data)
optimize!(m)
```

## Reading CSV SAM

```julia
data = prepare_data!(source=:csv, sam_path="data/csv/sam.csv")
m = model(data)
```

## Reading Excel SAM

```julia
data = prepare_data!(source=:excel, sam_path="data/linkage_100sector_data.xlsx")
m = model(data)
```

## Public API summary

- `init_data()` creates an empty `LinkageData` object.
- `prepare_data!()` creates/reads SAM, validates it, balances it, calibrates parameters, and precomputes `PAR`.
- `parameters(data)` returns precomputed `PAR`.
- `model(data)` initializes `Model(MCPModel())` and builds LINKAGE.
- `build_model(data)` is an alias-style builder returning a JuMP model.
- `build_linkage_model!(m, data)` builds into a user-provided JuMP model.
- `solve_model!(m)` calls `optimize!(m)`.
- `run_linkage!()` runs the complete pipeline and returns `(model, data)`.
