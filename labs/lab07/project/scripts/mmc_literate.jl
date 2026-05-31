# # M/M/c baseline experiment
#
# This file is used only for generation with Literate.jl.
# Run the ordinary script `scripts/mmc.jl` for the baseline experiment.

using DrWatson
@quickactivate "lab_07_des"

include(srcdir("QueueingModels.jl"))

# ## Run

QueueingModels.run_mmc_experiment(;
    lambda = 0.9,
    mu = 0.5,
    c = 2,
    num_customers = 5000,
    seed = 123,
)
