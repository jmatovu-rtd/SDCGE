# JuMP nonlinear interface fix

This version uses JuMP's **new nonlinear interface** consistently.

The previous version mixed:

- legacy nonlinear macros: `@NLconstraint`
- new nonlinear expressions created by modern JuMP parsing

That caused this runtime error when calling `optimize!`:

```julia
Cannot optimize a model which contains the features from both the legacy
(macros beginning with `@NL`) and new (`NonlinearExpr`) nonlinear interfaces.
```

Fix applied:

- replaced all `@NLconstraint` calls in `src/*.jl` with `@mapping/@complementarity`
- ensured no `@NL...` macros remain in the source tree
- kept nonlinear equations intact; JuMP now parses them through the new nonlinear interface only

Check:

```bash
grep -R "@NL" -n src
```

This should return no matches.
