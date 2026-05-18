# Usage:
#   julia examples/00_clean_api_full_pipeline.jl
#
# Cleanest one-call workflow. By default this prepares the SAM and builds the
# JuMP model without solving. Set solve=true to solve with PATH.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JuMP
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

m, data = run_linkage!(solve=false)

println("Built LINKAGE model.")
println("Activities/products: ", length(data.sets[:i]))
println("SAM accounts: ", length(data.sam_accounts[:all]))
println("JuMP variables: ", num_variables(m))
println("JuMP constraints: ", num_constraints(m; count_variable_in_set_constraints=false))
