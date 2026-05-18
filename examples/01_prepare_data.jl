# Usage:
#   julia examples/01_prepare_data.jl
#
# Prepare data only: default SAM -> validate -> RAS balance -> calibrate -> precompute.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

data = prepare_data!()
PAR = parameters(data)
summary = sam_balance_summary(data)

println("Prepared data.")
println("Activities/products: ", length(data.sets[:i]))
println("SAM accounts: ", length(data.sam_accounts[:all]))
println("Parameter tables: ", length(keys(PAR)))
println("Maximum balanced SAM row-column gap: ", summary[:max_abs_gap])
