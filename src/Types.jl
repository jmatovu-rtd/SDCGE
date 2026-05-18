# Usage:
#   data = init_data()
#   default_sets!(data)              # loads 100 activities/products and SAM account groups
#   setup_sam_accounts!(data)        # builds named SAM account lists
#
# This file contains only data containers and set/account defaults.

mutable struct LinkageData
    sets::Dict{Symbol,Vector}
    par::Dict{Symbol,Any}
    sam_accounts::Dict{Symbol,Vector{String}}
    sam::Matrix{Float64}
    balanced_sam::Matrix{Float64}
    sam_index::Dict{String,Int}
    metadata::Dict{Symbol,Any}
end

function LinkageData()
    return LinkageData(
        Dict{Symbol,Vector}(),
        Dict{Symbol,Any}(),
        Dict{Symbol,Vector{String}}(),
        zeros(0,0),
        zeros(0,0),
        Dict{String,Int}(),
        Dict{Symbol,Any}(),
    )
end

init_data() = LinkageData()

"""Create 100-activity/100-product LINKAGE sets.
Activities/products use P001..P100 so equations indexed by i,j,k remain compact.
"""
function default_sets!(data::LinkageData)
    S = data.sets
    products = ["P" * lpad(string(n), 3, "0") for n in 1:100]
    get!(S, :i, products)
    get!(S, :j, S[:i])
    get!(S, :k, S[:i])
    get!(S, :r, ["R1", "R2", "R3", "R4"])
    get!(S, :rp, S[:r])
    get!(S, :v, ["Old", "New"])
    get!(S, :l, ["UnSkLab", "SkLab"])
    get!(S, :ul, ["UnSkLab"])
    get!(S, :sl, ["SkLab"])
    get!(S, :h, ["HH"])
    get!(S, :f, ["Gov", "Inv"])
    get!(S, :in, ["HH", "Gov", "Inv"])
    get!(S, :t, [1, 2, 3])

    get!(S, :cr, products[1:10])
    get!(S, :lv, products[11:20])
    get!(S, :ag, vcat(S[:cr], S[:lv]))
    get!(S, :ip, [x for x in S[:i] if !(x in S[:ag])])
    get!(S, :e, products[71:75])
    get!(S, :ft, products[76:78])
    get!(S, :fd, products[1:10])
    get!(S, :nf, products[21:100])
    get!(S, :nnft, [x for x in S[:i] if !(x in S[:ft])])
    get!(S, :nnfd, [x for x in S[:i] if !(x in S[:fd])])
    get!(S, :gz, ["national", "urban", "rural"])
    get!(S, :gs, ["urban", "rural"])
    return data
end
