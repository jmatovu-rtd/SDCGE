# Run LINKAGE and show PATH solver progress on screen

include(joinpath(@__DIR__, "..", "src", "LinkageModel.jl"))
using .LinkageModel

# path_output="yes" prints PATH progress. Use "verbose" for more detail if supported.
m, data = run_linkage!(
    solve = true,
    show_solver_output = true,
    path_output = "yes",
    write_results = false,
    make_plots = false,
)

print_solver_status(m)
