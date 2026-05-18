# Usage:
#   julia examples/04_build_jump_model.jl
#
# Read the CSV SAM, prepare data, and build the JuMP model.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JuMP
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

sam_path = joinpath(@__DIR__, "..", "data", "csv", "sam.csv")
isfile(sam_path) || error("CSV SAM file not found: $(sam_path)")

data = prepare_data!(source=:csv, sam_path=sam_path)
m = model(data)

println("Built LINKAGE JuMP model from CSV SAM.")
println("Variables: ", num_variables(m))
println("Constraints: ", num_constraints(m; count_variable_in_set_constraints=false))
