using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

data = init_data()
default_sets!(data)
build_default_large_sam!(data)
balance_sam_ras!(data)
calibrate_from_sam!(data)
PAR = precompute_parameters(data)

@assert haskey(PAR, :KSupply)
@assert haskey(PAR, :LSupply)
@assert haskey(PAR, :TSupply)
@assert haskey(PAR, :FSupply)

println("KSupply sample: ", PAR[:KSupply][("P001", "Old")])
println("LSupply sample: ", PAR[:LSupply]["UnSkLab"])
println("TSupply sample: ", PAR[:TSupply]["P001"])
println("FSupply sample: ", PAR[:FSupply]["P001"])
println("Exogenous supply parameter check passed.")
