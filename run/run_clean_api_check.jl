# Usage:
#   julia run/run_clean_api_check.jl
#
# Smoke test for the cleaned API. It builds but does not solve by default.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JuMP
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

m, data = run_linkage!(solve=false)
println("Clean API check OK")
println("activities/products = ", length(data.sets[:i]))
println("sam accounts = ", length(data.sam_accounts[:all]))
println("variables = ", num_variables(m))
