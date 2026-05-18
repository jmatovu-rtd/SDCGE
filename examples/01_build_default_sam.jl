# Usage:
#   julia examples/01_build_default_sam.jl
#
# Build the internally generated default SAM and balance it.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

data = init_data()
default_sets!(data)
setup_sam_accounts!(data)
build_default_large_sam!(data)
validate_sam!(data; require_balanced=false)
balance_sam_ras!(data)
assert_balanced_sam!(data)

println("Default SAM accounts: ", length(data.sam_accounts[:all]))
println("Raw SAM size: ", size(data.sam))
println("Balanced SAM size: ", size(data.balanced_sam))
println("Maximum balanced SAM gap: ", sam_balance_summary(data)[:max_abs_gap])
