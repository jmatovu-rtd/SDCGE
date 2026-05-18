# Build the LINKAGE MCP model without solving and write equation diagnostics.
#
# Run from the project root:
#   julia --project=. examples/08_run_equation_diagnostics.jl

using LinkageModel

m, data = run_linkage!(solve=false, show_solver_output=false)

diag = diagnose_model(m; outdir=joinpath("results", "diagnostics"), write_csv=true, verbose=true)

println("Summary table:")
show(diag[:summary]; allrows=true, allcols=true)
println()
