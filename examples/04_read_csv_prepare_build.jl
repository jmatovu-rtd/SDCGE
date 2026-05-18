# Usage:
#   julia examples/04_read_csv_prepare_build.jl
#
# Same as 04_build_jump_model.jl, but using the default optimizer settings.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JuMP
include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

sam_path = joinpath(@__DIR__, "..", "data", "csv", "sam.csv")
isfile(sam_path) || error("CSV SAM file not found: $(sam_path)")

data = prepare_data!(source=:csv, sam_path=sam_path)
m = model(data)

println("CSV SAM model built.")
println("Balanced SAM size: ", size(data.balanced_sam))
println("Maximum balanced SAM gap: ", sam_balance_summary(data)[:max_abs_gap])
println("JuMP variables: ", num_variables(m))
