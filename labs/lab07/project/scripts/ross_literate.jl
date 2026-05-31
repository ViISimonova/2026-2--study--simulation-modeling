# # Ross model baseline experiment
#
# This file is used only for generation with Literate.jl.
# Run the ordinary script `scripts/ross.jl` for the baseline experiment.

using DrWatson
@quickactivate "lab_07_des"

include(srcdir("QueueingModels.jl"))

# ## Run

QueueingModels.run_ross_experiment(;
    N = 10,
    S = 3,
    repairers = 1,
    mean_time_to_failure = 100.0,
    mean_repair_time = 1.0,
    runs = 300,
    seed = 150,
)
