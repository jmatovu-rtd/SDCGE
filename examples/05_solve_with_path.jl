# Usage:
#   julia examples/05_solve_with_path.jl
#
# Full prepare -> build -> solve workflow with explicit PATH solver.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JuMP
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

data = prepare_data!()
m = model(data)
status = solve_model!(m)
println("PATH status: ", status)

results_dir = joinpath(@__DIR__, "..", "results")
export_results!(m, data; outdir=results_dir)
println("Results written to: ", results_dir)
