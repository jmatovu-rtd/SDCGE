# Usage:
#   julia examples/02_build_model_path.jl
#
# Prepare data and build a JuMP model with PATH.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JuMP
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

data = prepare_data!()
m = model(data)

println("Model built with PATH.")
println("JuMP variables: ", num_variables(m))
println("JuMP constraints: ", num_constraints(m; count_variable_in_set_constraints=false))
