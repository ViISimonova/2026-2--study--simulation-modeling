```@meta
EditURL = "../scripts/mmc_parameters_literate.jl"
```

# M/M/c parameter scan

This file is used only for generation with Literate.jl.
Run the ordinary script `scripts/mmc_parameters.jl` for the parameter scan.

````@example mmc_parameters
using DrWatson
@quickactivate "lab_07_des"

include(srcdir("QueueingModels.jl"))
````

## Run

````@example mmc_parameters
QueueingModels.run_mmc_parameter_scan(;
    lambdas = [0.3, 0.6, 0.9],
    channels = 1:6,
    mu = 0.5,
    num_customers = 3000,
    seed = 321,
)
````

