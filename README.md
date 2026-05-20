# LCGE-V4 — Economy-Wide Policy Simulation Model

LCGE-V4 is a Julia package that simulates how policy changes ripple through an entire economy. It models 100 sectors (agriculture, energy, manufacturing, services, and more) and finds the new equilibrium after a shock — showing you what happens to prices, production, employment, trade, and household income all at once.

---

## What problem does this solve?

Suppose a government raises import tariffs on fertilizer. That change affects:
- Farming costs → farm output prices → food prices for households
- Household budgets → savings and government tax revenue
- Export competitiveness → trade balances

Tracing all those knock-on effects by hand is impossible. This model solves thousands of equations simultaneously to find the new equilibrium where supply meets demand in every market.

---

## Before you start

You need two things installed before running anything.

### 1. Install Julia

Download from [julialang.org](https://julialang.org/downloads/). Version **1.9 or newer** is required. After installing, you should be able to open a terminal and type `julia` to start it.

### 2. Get a PATH Solver license

This model uses a specialized solver called **PATH** to find equilibria. It is free for academic use.

Follow the setup steps at the [PATHSolver.jl repository](https://github.com/chkwon/PATHSolver.jl) to obtain and install your license key. The license is set as an environment variable called `PATH_LICENSE_STRING`.

If you skip this step, you will get a license error when you try to solve.

---

## Installation

Open a terminal, navigate to this folder, and start Julia:

```
julia
```

Then run:

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

This downloads all required libraries (JuMP, PATHSolver, DataFrames, XLSX, Complementarity). It only needs to be done once.

---

## Your first run (5 lines)

```julia
include("src/LinkageModel.jl")
using .LinkageModel

data = init_data()       # Step 1: create a blank data container
prepare_data!(data)      # Step 2: load the built-in example economy and calibrate it
m = model(data)          # Step 3: build the model equations
solve_model!(m)          # Step 4: find the equilibrium
export_results!(m, data) # Step 5: save results to the results/ folder
```

The package ships with a synthetic 100-sector economy, so you can run this immediately without any external data files. Results appear as CSV files in the `results/` folder.

**One-line shortcut** that does all five steps:

```julia
include("src/LinkageModel.jl")
using .LinkageModel
m, data = run_linkage!()
```

---

## Understanding the output

After solving, the `results/` folder contains:

| File | Contents |
|------|----------|
| `results_all_variables.csv` | Every model variable — solution value, starting value, and percentage change |
| `results_XP.csv` | Gross output by sector |
| `results_GDP.csv` | GDP by region |
| `results_YH.csv` | Household income |
| `results_YD.csv` | Disposable income |
| `results_YC.csv` | Consumption expenditure |
| `results_SAV.csv` | Household saving |
| `results_GOVREV.csv` | Government revenue |
| `results_metadata.csv` | Solver status and timestamp |
| `sam_balance_table.csv` | SAM row/column balance diagnostics |

You can also get results as a Julia table without saving files:

```julia
df = results_dataframe(m, data)
```

The `pct_change_from_start` column in the results shows the percentage change from the baseline for each variable. A value of `5.0` means the variable increased by 5% relative to the calibrated benchmark.

---

## Using your own economy data

The model reads its economy from a **Social Accounting Matrix (SAM)** — a square table recording all money flows between sectors, households, government, and the rest of the world for a base year.

### Option A: Load from a CSV file

Your CSV must have account labels in the first row and first column. The package expects **406 accounts** in the standard order (activities, commodities, factors, taxes, institutions, margins).

```julia
data = init_data()
prepare_data!(data;
    source        = :csv,
    sam_path      = "data/csv/sam.csv",
    accounts_path = "data/csv/sam_accounts.csv",
    sets_path     = "data/csv/sets.csv"
)
m = model(data)
solve_model!(m)
```

### Option B: Load from an Excel file

```julia
data = init_data()
prepare_data!(data;
    source     = :excel,
    sam_path   = "data/linkage_100sector_data.xlsx"
)
m = model(data)
solve_model!(m)
```

The package automatically checks and balances your SAM before calibrating. Balancing diagnostics are written to `results/sam_balance_table.csv` — check this file if you are unsure whether your SAM is suitable.

---

## Applying a policy shock

To simulate a policy change, modify the calibrated parameters **after** `prepare_data!` and **before** `model(data)`.

**Example: increase the import tariff on commodity P001 between regions R1 and R2 to 20%**

```julia
data = init_data()
prepare_data!(data)

# Change one tariff rate in the precomputed parameter table
data.metadata[:PAR][:tau_m][("R1", "R2", "P001")] = 0.20

m = model(data)   # builds the model with the new tariff
solve_model!(m)
export_results!(m, data)
```

All calibrated parameters live in `data.metadata[:PAR]`. Common ones to modify:

| Parameter | Description | Index |
|-----------|-------------|-------|
| `tau_m` | Import tariff rate | `(destination, origin, product)` |
| `tau_e` | Export tax rate | `(origin, destination, product)` |
| `tau_p` | Output tax rate | `(product)` |
| `AT` | Total factor productivity | `(product)` |
| `LSupply` | Labor supply | `("UnSkLab")` or `("SkLab")` |

---

## Step-by-step example scripts

The `examples/` folder contains runnable scripts:

| Script | What it shows |
|--------|---------------|
| `01_prepare_data.jl` | Load and balance a SAM |
| `02_build_model_path.jl` | Build the model without solving |
| `05_solve_with_path.jl` | Solve and save results |
| `06_solve_export_results_and_plot.jl` | Full run with charts |

Run any script from the terminal:

```
julia examples/01_prepare_data.jl
```

---

## Checking that the model built correctly

Before solving, you can print a quick health check:

```julia
print_model_diagnostics(m)
```

This shows the number of variables and constraints. For the 100-sector model you should see several thousand of each. If the counts are much lower than expected, something went wrong during the build step.

---

## Common problems and fixes

**"PATH license not found" or license error**
: Set the `PATH_LICENSE_STRING` environment variable before starting Julia. See the [PATHSolver.jl README](https://github.com/chkwon/PATHSolver.jl) for instructions.

**Solver reports "Did not converge" or status is not `OPTIMAL`**
: The starting point may be too far from a valid solution. Check that your SAM is balanced (`results/sam_balance_table.csv`), and that parameter values are realistic. Try running with the default synthetic SAM first to confirm the base model works.

**"SAM is not balanced" error**
: Your input SAM has row totals that differ from column totals. The package runs RAS balancing automatically, but if the imbalances are very large the result may not be meaningful. Check your data source.

**Very slow solve or PATH runs for many iterations**
: Large parameter changes (e.g., a tariff jumping from 0% to 100%) can make the problem hard to solve from a benchmark starting point. Try a smaller shock first, or use the previous solution as a starting point for a larger shock.

---

## Project layout

```
LCGE-V4/
├── src/             Model source code — do not edit unless modifying the model
├── data/            Example economy data (SAM in Excel and CSV formats)
├── examples/        Runnable walkthrough scripts — start here
├── results/         Output files created after each run
├── docs/            Technical notes and equation-coverage audits
└── Project.toml     Julia dependency list (managed automatically)
```

You only need to interact with:
- `data/` — to supply your own SAM
- `examples/` — to run the model
- `results/` — to read the output

---

## What the model covers

| Feature | Detail |
|---------|--------|
| Sectors | 100 (crops P001–P010, livestock P011–P020, energy P071–P075, industry and services P021–P100) |
| Regions | 4 |
| Labor types | Unskilled and skilled, with rural/urban zones and migration |
| Capital | Old (installed) and new (investment), with sector-specific allocation |
| Trade | Nested import demand (Armington), export allocation (CET), tariff-rate quotas |
| Government | Output, intermediate, trade, factor, and income taxes; fiscal balance |
| Households | Full income distribution and consumption demand system (ELES/AIDADS) |
| Dynamics | Productivity growth, population, capital accumulation (optional multi-period) |
