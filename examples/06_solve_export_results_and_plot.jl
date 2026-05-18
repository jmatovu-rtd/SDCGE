# Usage:
#   julia examples/06_solve_export_results_and_plot.jl
#
# Solve the model, write CSV result files, and create plots if Plots.jl is installed.
# To install plotting support:
#   julia --project=. -e 'import Pkg; Pkg.add("Plots")'

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

try
    plot_files = plot_results(results_dir; outdir=joinpath(results_dir, "plots"))
    println("Plot files written:")
    foreach(println, plot_files)
catch err
    @warn "Plots were not created. Install Plots.jl to enable plotting." exception=(err, catch_backtrace())
end
