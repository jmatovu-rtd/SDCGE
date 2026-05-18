using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JuMP
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

println("== LINKAGE 100-sector build check ==")
data = init_data()
default_sets!(data)
setup_sam_accounts!(data)
println("Products: ", length(data.sets[:i]))
println("SAM accounts: ", length(data.sam_accounts[:all]))

# CSV is preferred for robust automated runs.
read_sam_csv!(data, joinpath(@__DIR__, "..", "data", "csv", "sam.csv"))
println("Raw SAM size: ", size(data.sam))
balance_sam_ras!(data)
calibrate_from_sam!(data)

model = LinkageModel.model(data)
println("Variables: ", num_variables(model))
println("Constraints: ", num_constraints(model; count_variable_in_set_constraints=false))
println("Done.")
