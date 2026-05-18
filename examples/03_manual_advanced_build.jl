# Usage:
#   julia examples/03_manual_advanced_build.jl
#
# Advanced pattern: initialize the JuMP model manually, then call build_linkage_model!.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JuMP
using PATHSolver
using Complementarity
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

data = prepare_data!()
m = Model(PATHSolver.Optimizer)
build_linkage_model!(m, data)

println("Manual build complete.")
println("JuMP variables: ", num_variables(m))
println("JuMP constraints: ", num_constraints(m; count_variable_in_set_constraints=false))
