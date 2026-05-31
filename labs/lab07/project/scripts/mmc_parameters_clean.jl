using DrWatson
@quickactivate "lab_07_des"

include(srcdir("QueueingModels.jl"))

QueueingModels.run_mmc_parameter_scan(;
    lambdas = [0.3, 0.6, 0.9],
    channels = 1:6,
    mu = 0.5,
    num_customers = 3000,
    seed = 321,
)
