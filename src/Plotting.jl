# Optional plotting utilities for LCGE/LINKAGE results.
#
# These functions require Plots.jl:
#
#     import Pkg
#     Pkg.add("Plots")
#
# Typical use:
#
#     solve_model!(m)
#     export_results!(m, data; outdir="results")
#     plot_results("results"; outdir="results/plots")
#
# This file is included by the main module, but Plots.jl is loaded only inside
# plotting functions so the model can still build and solve without it.

function _lcge_parse_results_csv(path::AbstractString)
    lines = readlines(path)
    isempty(lines) && return NamedTuple[]
    header = split(lines[1], ",")
    rows = NamedTuple[]
    for line in lines[2:end]
        cols = split(line, ",")
        length(cols) < length(header) && continue
        nt = (; Dict(Symbol(header[i]) => cols[i] for i in eachindex(header))...)
        push!(rows, nt)
    end
    return rows
end

function _lcge_try_float(x)
    try
        return parse(Float64, string(x))
    catch
        return NaN
    end
end

function _lcge_plot_variable(results_dir::AbstractString, variable_name::AbstractString, outdir::AbstractString)
    @eval import Plots

    path = joinpath(results_dir, "results_$(variable_name).csv")
    if !isfile(path)
        return nothing
    end

    rows = _lcge_parse_results_csv(path)
    isempty(rows) && return nothing

    labels = [string(r.index) for r in rows]
    values = [_lcge_try_float(r.value) for r in rows]

    keep = .!isnan.(values)
    labels = labels[keep]
    values = values[keep]

    isempty(values) && return nothing

    # Keep plots readable for large models.
    max_items = min(length(values), 30)
    labels = labels[1:max_items]
    values = values[1:max_items]

    plt = Plots.bar(
        labels,
        values;
        legend=false,
        title="$(variable_name) results",
        xlabel="Index",
        ylabel="Value",
        xrotation=45,
        size=(1000, 600),
        margin=8Plots.mm,
    )

    mkpath(outdir)
    outfile = joinpath(outdir, "plot_$(variable_name).png")
    Plots.savefig(plt, outfile)
    return outfile
end

"""Create PNG plots from exported result files.

By default this plots key variables if their CSV files exist:
`XP`, `GDP`, `RGDP`, `CPI`, `XM`, `E`, `YH`, and `SAV`.
"""
function plot_results(results_dir::AbstractString="results"; outdir::AbstractString=joinpath(results_dir, "plots"), variables=["XP", "GDP", "RGDP", "CPI", "XM", "E", "YH", "SAV"])
    mkpath(outdir)
    files = String[]
    for vname in variables
        f = _lcge_plot_variable(results_dir, string(vname), outdir)
        if f !== nothing
            push!(files, f)
        end
    end
    return files
end

"""Convenience function: export CSV results and create plots."""
function export_results_and_plots!(m, data::LinkageData; results_dir::AbstractString="results", plots_dir::AbstractString=joinpath(results_dir, "plots"))
    export_results!(m, data; outdir=results_dir)
    return plot_results(results_dir; outdir=plots_dir)
end
