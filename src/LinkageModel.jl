module LinkageModel

using JuMP
using LinearAlgebra
using DelimitedFiles
using XLSX
using Complementarity
using PATHSolver
using DataFrames

include("Types.jl")
include("SAM.jl")
include("Calibration.jl")
include("ParameterTables.jl")
include("Functions.jl")
include("Initialization.jl")
include("Variables.jl")
include("Production.jl")
include("Income.jl")
include("Demand.jl")
include("Trade.jl")
include("Equilibrium.jl")
include("Closure.jl")
include("Factors.jl")
include("Other.jl")
include("Dynamics.jl")
include("Accounting.jl")
include("Results.jl")
include("Plotting.jl")
include("Diagnostics.jl")
include("ModelBuilder.jl")

export LinkageData, init_data, default_sets!, setup_sam_accounts!, build_default_large_sam!,
       read_sam_csv!, read_sam_excel!, validate_sam!, balance_sam_ras!, sam_balance_table, sam_balance_summary, assert_balanced_sam!, export_sam_balance_report!, export_balanced_sam!, calibrate_from_sam!,
       precompute_parameters, sanitize_parameters!, parameter_diagnostics, parameters, prepare_data!, add_variables!, initialize_from_sam!, enforce_nlp_safe_bounds_and_starts!, initialization_diagnostics, check_initialization!,
       results_dataframe, export_results!, solve_and_save!, plot_results, export_results_and_plots!,
       ces_demand, ces_price, ces_alpha, cet_supply, cet_price, cet_gamma_from_primal, cet_primal_from_gamma,
       armington_market_shares, armington_beta, armington_alpha_update, armington_long_run_elasticity, build_linkage_model!,
       build_model, model, solve_model!, solve_linkage!, run_linkage!, run_model!, print_model_diagnostics, print_solver_status,
       diagnose_model, print_equation_diagnostics, diagnostic_variables, diagnostic_constraints,
       diagnostic_equation_matches, diagnostic_variables_without_equations,
       diagnostic_variables_with_multiple_equations, diagnostic_redundant_equations

end
