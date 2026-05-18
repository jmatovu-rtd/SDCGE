# Results export utilities for solved LCGE/LINKAGE JuMP models.
#
# Typical use after solving:
#
#     solve_model!(m)
#     export_results!(m, data; outdir="results")
#
# Or:
#
#     solve_and_save!(m, data; outdir="results")
#
# The code avoids a hard dependency on CSV.jl. CSV files are written directly
# using Base I/O so the existing Project.toml remains lightweight.

using Dates

function _lcge_csv_escape(x)
    s = string(x)
    if occursin(",", s) || occursin("\"", s) || occursin("\n", s) || occursin("\r", s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function _lcge_write_csv(path::AbstractString, header, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(_lcge_csv_escape.(header), ","))
        for row in rows
            println(io, join(_lcge_csv_escape.(row), ","))
        end
    end
    return path
end

function _lcge_value(v::JuMP.VariableRef)
    try
        return result_value(v)
    catch
        return missing
    end
end

function _lcge_start_value(v::JuMP.VariableRef)
    try
        sv = start_value(v)
        return sv === nothing ? missing : sv
    catch
        return missing
    end
end

function _lcge_index_string(idx)
    if idx isa Tuple
        return join(string.(idx), "|")
    else
        return string(idx)
    end
end

function _lcge_collect_variable_rows!(rows::Vector{Vector{Any}}, name::Symbol, obj)
    if obj isa JuMP.VariableRef
        val = _lcge_value(obj)
        start = _lcge_start_value(obj)
        diff = (val === missing || start === missing) ? missing : val - start
        pct = (val === missing || start === missing || abs(start) <= 1.0e-12) ? missing : 100.0 * (val - start) / start
        push!(rows, Any[string(name), "", val, start, diff, pct])
        return rows
    end

    # JuMP containers support pairs(container). This covers DenseAxisArray,
    # SparseAxisArray, and normal Arrays of VariableRef.
    try
        for (idx, var) in pairs(obj)
            if var isa JuMP.VariableRef
                val = _lcge_value(var)
                start = _lcge_start_value(var)
                diff = (val === missing || start === missing) ? missing : val - start
                pct = (val === missing || start === missing || abs(start) <= 1.0e-12) ? missing : 100.0 * (val - start) / start
                push!(rows, Any[string(name), _lcge_index_string(idx), val, start, diff, pct])
            end
        end
    catch
        # Ignore non-variable JuMP objects.
    end
    return rows
end

"""Return a flat DataFrame with one row per model variable element.

Columns:
- `variable`: JuMP container name
- `index`: pipe-separated index label
- `value`: solution value
- `start_value`: initialization value
- `change_from_start`: solution minus start value
- `pct_change_from_start`: percentage change from start value
"""
function results_dataframe(m)
    rows = Vector{Vector{Any}}()
    for (name, obj) in object_dictionary(m)
        _lcge_collect_variable_rows!(rows, name, obj)
    end
    return DataFrame(
        variable = [r[1] for r in rows],
        index = [r[2] for r in rows],
        value = [r[3] for r in rows],
        start_value = [r[4] for r in rows],
        change_from_start = [r[5] for r in rows],
        pct_change_from_start = [r[6] for r in rows],
    )
end

function _lcge_rows_from_dataframe(df::DataFrame)
    rows = Vector{Vector{Any}}()
    for r in eachrow(df)
        push!(rows, Any[r.variable, r.index, r.value, r.start_value, r.change_from_start, r.pct_change_from_start])
    end
    return rows
end

function _lcge_variable_rows(df::DataFrame, variable_name::AbstractString)
    rows = Vector{Vector{Any}}()
    for r in eachrow(df)
        if string(r.variable) == variable_name
            push!(rows, Any[r.index, r.value, r.start_value, r.change_from_start, r.pct_change_from_start])
        end
    end
    return rows
end

function _lcge_scalar_rows(m)
    rows = Vector{Vector{Any}}()
    for (name, obj) in object_dictionary(m)
        if obj isa JuMP.VariableRef
            push!(rows, Any[string(name), _lcge_value(obj), _lcge_start_value(obj)])
        end
    end
    return rows
end

function _lcge_metadata_rows(m)
    rows = Vector{Vector{Any}}()
    push!(rows, Any["created_at", string(now())])
    try
        push!(rows, Any["termination_status", string(termination_status(m))])
    catch
        push!(rows, Any["termination_status", "not_available"])
    end
    try
        push!(rows, Any["primal_status", string(primal_status(m))])
    catch
        push!(rows, Any["primal_status", "not_available"])
    end
    try
        push!(rows, Any["dual_status", string(dual_status(m))])
    catch
        push!(rows, Any["dual_status", "not_available"])
    end
    return rows
end

"""Export solution results to CSV files.

Files written:
- `results_all_variables.csv`
- `results_scalars.csv`
- `results_metadata.csv`
- one file per common variable, for example `results_XP.csv`, `results_GDP.csv`

Returns the full results DataFrame.
"""
function export_results!(m, data::LinkageData; outdir::AbstractString="results")
    mkpath(outdir)

    # Always export and verify the SAM balance report alongside model results.
    export_sam_balance_report!(data; outdir=outdir)

    df = results_dataframe(m)

    _lcge_write_csv(
        joinpath(outdir, "results_all_variables.csv"),
        ["variable", "index", "value", "start_value", "change_from_start", "pct_change_from_start"],
        _lcge_rows_from_dataframe(df),
    )

    _lcge_write_csv(
        joinpath(outdir, "results_scalars.csv"),
        ["variable", "value", "start_value"],
        _lcge_scalar_rows(m),
    )

    _lcge_write_csv(
        joinpath(outdir, "results_metadata.csv"),
        ["item", "value"],
        _lcge_metadata_rows(m),
    )

    common_variables = [
        "XP", "XA", "XD", "XQ", "ND", "VA", "XM", "E", "D",
        "GDP", "RGDP", "CPI", "PGDP", "YH", "YD", "YC", "SAV",
        "INVEST", "SAVE", "GOVREV", "GEXP", "TAXREV"
    ]

    for vname in common_variables
        rows = _lcge_variable_rows(df, vname)
        if !isempty(rows)
            _lcge_write_csv(
                joinpath(outdir, "results_$(vname).csv"),
                ["index", "value", "start_value", "change_from_start", "pct_change_from_start"],
                rows,
            )
        end
    end

    return df
end

"""Solve the model and immediately export result files."""
function solve_and_save!(m, data::LinkageData; outdir::AbstractString="results")
    solve_model!(m)
    export_results!(m, data; outdir=outdir)
    return m
end
