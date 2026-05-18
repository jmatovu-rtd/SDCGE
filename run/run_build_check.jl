using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using JuMP
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

data = init_data()
read_sam_csv!(data, joinpath(@__DIR__, "..", "data", "csv", "sam.csv"))
balance_sam_ras!(data)
calibrate_from_sam!(data)
model = LinkageModel.model(data)
println("Products: ", length(data.sets[:i]))
println("SAM accounts: ", length(data.sam_accounts[:all]))
println("Variables: ", num_variables(model))
println("Constraints: ", num_constraints(model; count_variable_in_set_constraints=false))
println("Build completed.")
