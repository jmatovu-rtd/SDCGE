# LCGE examples

Run examples from the project root or directly by file path, for example:

```bash
julia examples/01_prepare_data.jl
julia examples/02_build_model_path.jl
julia examples/05_solve_with_path.jl
```

Recommended order:

1. `01_prepare_data.jl` — checks data preparation and SAM balancing.
2. `02_build_model_path.jl` — builds the JuMP model.
3. `05_solve_with_path.jl` — solves and exports results.
4. `06_solve_export_results_and_plot.jl` — solves, exports results, and plots if `Plots.jl` is installed.

CSV and Excel examples use the files in `data/csv/` and `data/linkage_100sector_data.xlsx`.
