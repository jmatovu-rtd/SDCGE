# Diagnostics for LINKAGE/JuMP MCP models.
#
# The earlier version tried to discover the variable matched to each equation by
# parsing the printed constraint text after the unicode complementarity symbol.
# That is unreliable because JuMP/Complementarity may store MCP constraints as
# MOI.Complements objects whose printed form does not contain `⟂`.  This version
# inspects the MathOptInterface constraint function directly and uses the second
# component of each MOI.Complements constraint as the matched variable.
#
# Main entry points:
#   diagnose_model(m; outdir="results/diagnostics")
#   print_equation_diagnostics(m)

using DataFrames
const MOI = JuMP.MOI

# -----------------------------------------------------------------------------
# Small utilities
# -----------------------------------------------------------------------------

function _diag_name(x)
    try
        n = JuMP.name(x)
        return isempty(n) ? string(x) : n
    catch
        return string(x)
    end
end

_diag_family_name(s::AbstractString) = replace(String(s), r"\[.*\]" => "")
_diag_norm_text(s::AbstractString) = replace(String(s), r"\s+" => "")

function _diag_csv_escape(x)
    s = x === missing ? "" : string(x)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s) || occursin('\r', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function _diag_write_csv(path::AbstractString, df::DataFrame)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(_diag_csv_escape.(names(df)), ","))
        for row in eachrow(df)
            println(io, join((_diag_csv_escape(row[c]) for c in names(df)), ","))
        end
    end
    return path
end

function _diag_var_lookup(m)
    d = Dict{String,String}()
    for v in JuMP.all_variables(m)
        d[string(JuMP.index(v))] = _diag_name(v)
    end
    return d
end

# -----------------------------------------------------------------------------
# Generic MOI-function variable extraction
# -----------------------------------------------------------------------------

function _diag_push_var!(acc::Set{String}, v::MOI.VariableIndex)
    push!(acc, string(v))
    return acc
end

function _diag_collect_vars!(acc::Set{String}, x; output_index::Union{Nothing,Int}=nothing)
    x isa Number && return acc
    x isa AbstractString && return acc
    x isa Symbol && return acc
    x isa MOI.VariableIndex && return _diag_push_var!(acc, x)

    # Vector affine/quadratic terms carry their row/component separately.  For a
    # complementarity constraint the equation residual is usually component 1 and
    # the complementarity variable is component 2.
    if hasproperty(x, :output_index)
        oi = getproperty(x, :output_index)
        output_index !== nothing && oi != output_index && return acc
        if hasproperty(x, :scalar_term)
            return _diag_collect_vars!(acc, getproperty(x, :scalar_term); output_index=nothing)
        end
    end

    for p in (:variable, :variable_1, :variable_2)
        if hasproperty(x, p)
            _diag_collect_vars!(acc, getproperty(x, p); output_index=nothing)
        end
    end

    # Common MOI containers.  Keep this property-based so it works across JuMP
    # versions and for affine, quadratic, and nonlinear vector functions.
    for p in (:terms, :affine_terms, :quadratic_terms, :rows)
        if hasproperty(x, p)
            for y in getproperty(x, p)
                _diag_collect_vars!(acc, y; output_index=output_index)
            end
        end
    end

    # Nonlinear functions may use fields named head/args or expressions with
    # args.  We only recurse into obvious iterable argument lists, not into all
    # fields, to avoid walking internal model objects.
    for p in (:args, :arguments)
        if hasproperty(x, p)
            for y in getproperty(x, p)
                _diag_collect_vars!(acc, y; output_index=output_index)
            end
        end
    end

    return acc
end

function _diag_vars_in_function(func; output_index::Union{Nothing,Int}=nothing)
    acc = Set{String}()
    _diag_collect_vars!(acc, func; output_index=output_index)
    return collect(acc)
end

function _diag_constraint_object(c)
    try
        return JuMP.constraint_object(c)
    catch
        return nothing
    end
end

_diag_is_complements_set(S) = (S <: MOI.Complements) || occursin("Complements", string(S))

function _diag_complement_var_names_from_text(text::AbstractString)
    occursin('⟂', text) || return String[]
    rhs = strip(split(String(text), '⟂')[end])
    rhs = replace(rhs, r"\s+" => "")
    rhs = replace(rhs, r";$" => "")
    return isempty(rhs) ? String[] : [rhs]
end

# -----------------------------------------------------------------------------
# Public diagnostics
# -----------------------------------------------------------------------------

"""Return all JuMP variables with stable MOI ids and printable names."""
function diagnostic_variables(m)
    vars = JuMP.all_variables(m)
    return DataFrame(
        variable_index = [string(JuMP.index(v)) for v in vars],
        variable = [_diag_name(v) for v in vars],
        family = [_diag_family_name(_diag_name(v)) for v in vars],
    )
end

"""Collect model constraints.  Complementarity constraints are marked explicitly."""
function diagnostic_constraints(m)
    rows = NamedTuple[]
    for (F, S) in JuMP.list_of_constraint_types(m)
        for c in JuMP.all_constraints(m, F, S)
            cname = _diag_name(c)
            cstr = string(c)
            is_comp = _diag_is_complements_set(S) || occursin('⟂', cstr)
            push!(rows, (
                constraint = cname,
                family = _diag_family_name(cname),
                f_type = string(F),
                set_type = string(S),
                is_complementarity = is_comp,
                text = cstr,
            ))
        end
    end
    return DataFrame(rows)
end

"""
Return equation-to-variable MCP matches.

For true MOI.Complements constraints, this uses variables appearing in component
2 of the vector function.  This avoids the false result where every variable is
reported as unmatched because the printed constraint text omitted `⟂`.
"""
function diagnostic_equation_matches(m)
    lookup = _diag_var_lookup(m)
    rows = NamedTuple[]

    for (F, S) in JuMP.list_of_constraint_types(m)
        is_comp_type = _diag_is_complements_set(S)
        for c in JuMP.all_constraints(m, F, S)
            cname = _diag_name(c)
            ctext = string(c)
            is_comp = is_comp_type || occursin('⟂', ctext)
            is_comp || continue

            obj = _diag_constraint_object(c)
            comp_ids = String[]
            residual_ids = String[]
            method = "text"

            if obj !== nothing && hasproperty(obj, :func) && is_comp_type
                func = getproperty(obj, :func)
                comp_ids = _diag_vars_in_function(func; output_index=2)
                residual_ids = _diag_vars_in_function(func; output_index=1)
                method = "MOI component 2"
            end

            # Fallback for older Complementarity.jl printed forms.
            comp_names_from_text = String[]
            if isempty(comp_ids)
                comp_names_from_text = _diag_complement_var_names_from_text(ctext)
            end

            if !isempty(comp_ids)
                for vid in sort(comp_ids)
                    vname = get(lookup, vid, vid)
                    push!(rows, (
                        constraint = cname,
                        constraint_family = _diag_family_name(cname),
                        complement_variable_index = vid,
                        complement_variable = vname,
                        complement_family = _diag_family_name(vname),
                        residual_variable_count = length(residual_ids),
                        extraction_method = method,
                        text = ctext,
                    ))
                end
            else
                for vname in comp_names_from_text
                    push!(rows, (
                        constraint = cname,
                        constraint_family = _diag_family_name(cname),
                        complement_variable_index = "",
                        complement_variable = vname,
                        complement_family = _diag_family_name(vname),
                        residual_variable_count = 0,
                        extraction_method = method,
                        text = ctext,
                    ))
                end
            end
        end
    end

    return DataFrame(rows)
end

"""Find variables with no MCP complementarity equation."""
function diagnostic_variables_without_equations(m)
    vars = diagnostic_variables(m)
    matches = diagnostic_equation_matches(m)
    if nrow(matches) == 0
        return vars
    end

    matched_ids = Set(String.(matches.complement_variable_index[matches.complement_variable_index .!= ""]))
    matched_names = Set(String.(matches.complement_variable[matches.complement_variable_index .== ""]))

    keep = [!(row.variable_index in matched_ids) && !(row.variable in matched_names) for row in eachrow(vars)]
    return vars[keep, :]
end

"""Find variables matched by multiple MCP equations."""
function diagnostic_variables_with_multiple_equations(m)
    matches = diagnostic_equation_matches(m)
    nrow(matches) == 0 && return DataFrame(
        complement_variable=String[], complement_variable_index=String[], equation_count=Int[],
        constraints=String[], constraint_families=String[])

    key = [isempty(r.complement_variable_index) ? r.complement_variable : r.complement_variable_index for r in eachrow(matches)]
    tmp = copy(matches)
    tmp[!, :match_key] = key
    g = combine(groupby(tmp, :match_key),
        :complement_variable => first => :complement_variable,
        :complement_variable_index => first => :complement_variable_index,
        nrow => :equation_count,
        :constraint => (x -> join(x, "; ")) => :constraints,
        :constraint_family => (x -> join(unique(x), "; ")) => :constraint_families,
    )
    return sort(g[g.equation_count .> 1, :], :equation_count, rev=true)
end

"""Flag likely duplicate, tautological, or placeholder equations."""
function diagnostic_redundant_equations(m)
    matches = diagnostic_equation_matches(m)
    rows = NamedTuple[]
    seen_residual = Dict{String,Vector{String}}()

    for row in eachrow(matches)
        lhs = occursin('⟂', row.text) ? split(row.text, '⟂')[1] : row.text
        norm_lhs = _diag_norm_text(lhs)
        push!(get!(seen_residual, norm_lhs, String[]), row.constraint)

        reasons = String[]
        if occursin(r"\b([A-Za-z_]\w*(?:\[[^\]]+\])?)-\1\b", norm_lhs)
            push!(reasons, "tautology: variable minus itself")
        end
        if norm_lhs in ("0", "(0)") || occursin(r"(^|[=+\-*/(])0($|[)+\-*/])", norm_lhs)
            push!(reasons, "zero/placeholder residual candidate")
        end
        if !isempty(reasons)
            push!(rows, (
                constraint = row.constraint,
                complement_variable = row.complement_variable,
                reason = join(reasons, "; "),
                text = row.text,
            ))
        end
    end

    for (norm, cnames) in seen_residual
        if length(cnames) > 1
            push!(rows, (
                constraint = join(cnames, "; "),
                complement_variable = "",
                reason = "duplicate residual text",
                text = norm,
            ))
        end
    end
    return DataFrame(rows)
end

"""
Summarise model diagnostics and optionally write CSV files under `outdir`.

Files:
- variables.csv
- constraints.csv
- equation_matches.csv
- variables_without_equations.csv
- variables_with_multiple_equations.csv
- likely_redundant_equations.csv
- diagnostic_summary.csv
"""
function diagnose_model(m; outdir::AbstractString=joinpath("results", "diagnostics"), write_csv::Bool=true, verbose::Bool=true)
    vars = diagnostic_variables(m)
    cons = diagnostic_constraints(m)
    matches = diagnostic_equation_matches(m)
    missing = diagnostic_variables_without_equations(m)
    multiple = diagnostic_variables_with_multiple_equations(m)
    redundant = diagnostic_redundant_equations(m)

    summary = DataFrame(metric = String[], value = Int[])
    push!(summary, ("variables", nrow(vars)))
    push!(summary, ("constraints_total", nrow(cons)))
    push!(summary, ("complementarity_constraints", count(cons.is_complementarity)))
    push!(summary, ("equation_variable_matches", nrow(matches)))
    push!(summary, ("variables_without_equations", nrow(missing)))
    push!(summary, ("variables_with_multiple_equations", nrow(multiple)))
    push!(summary, ("likely_redundant_equations", nrow(redundant)))

    if write_csv
        mkpath(outdir)
        _diag_write_csv(joinpath(outdir, "variables.csv"), vars)
        _diag_write_csv(joinpath(outdir, "constraints.csv"), cons)
        _diag_write_csv(joinpath(outdir, "equation_matches.csv"), matches)
        _diag_write_csv(joinpath(outdir, "variables_without_equations.csv"), missing)
        _diag_write_csv(joinpath(outdir, "variables_with_multiple_equations.csv"), multiple)
        _diag_write_csv(joinpath(outdir, "likely_redundant_equations.csv"), redundant)
        _diag_write_csv(joinpath(outdir, "diagnostic_summary.csv"), summary)
    end

    if verbose
        print_equation_diagnostics(m; max_rows=20)
        write_csv && println("Diagnostic CSV files written to: ", outdir)
    end

    return Dict(
        :summary => summary,
        :variables => vars,
        :constraints => cons,
        :equation_matches => matches,
        :variables_without_equations => missing,
        :variables_with_multiple_equations => multiple,
        :likely_redundant_equations => redundant,
    )
end

function print_equation_diagnostics(m; max_rows::Int=20)
    vars = diagnostic_variables(m)
    cons = diagnostic_constraints(m)
    matches = diagnostic_equation_matches(m)
    missing = diagnostic_variables_without_equations(m)
    multiple = diagnostic_variables_with_multiple_equations(m)
    redundant = diagnostic_redundant_equations(m)

    println("\n================ EQUATION DIAGNOSTICS ================")
    println("Variables:                         ", nrow(vars))
    println("Constraints total:                 ", nrow(cons))
    println("Complementarity constraints:        ", count(cons.is_complementarity))
    println("Equation-variable matches:          ", nrow(matches))
    println("Variables without equations:        ", nrow(missing))
    println("Variables with multiple equations:  ", nrow(multiple))
    println("Likely redundant/placeholders:      ", nrow(redundant))

    if nrow(matches) == 0 && count(cons.is_complementarity) > 0
        println("\nWARNING: Complementarity constraints exist, but no matched variables were extracted.")
        println("Inspect constraints.csv and equation_matches.csv; this may indicate a JuMP/MOI representation not covered by Diagnostics.jl.")
    end

    if nrow(missing) > 0
        println("\nFirst variables without equations:")
        show(first(missing, min(max_rows, nrow(missing))); allcols=true, truncate=100)
        println()
    end
    if nrow(multiple) > 0
        println("\nFirst variables matched by multiple equations:")
        show(first(multiple, min(max_rows, nrow(multiple))); allcols=true, truncate=100)
        println()
    end
    if nrow(redundant) > 0
        println("\nFirst likely redundant/placeholders:")
        show(first(redundant, min(max_rows, nrow(redundant))); allcols=true, truncate=100)
        println()
    end
    println("======================================================\n")
    return nothing
end
