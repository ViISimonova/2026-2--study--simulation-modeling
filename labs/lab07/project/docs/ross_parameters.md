```@meta
EditURL = "../scripts/ross_parameters_literate.jl"
```

# Ross model parameter scan

This file is used only for generation with Literate.jl.
Run the ordinary script `scripts/ross_parameters.jl` for the parameter scan.

````@example ross_parameters
using DrWatson
@quickactivate "lab_07_des"

include(srcdir("QueueingModels.jl"))
````

## Run

````@example ross_parameters
QueueingModels.run_ross_parameter_scan(;
    N_values = [5, 10, 15],
    S_values = [1, 3],
    repairer_values = [1, 2],
    mean_time_to_failure = 100.0,
    mean_repair_time = 1.0,
    runs = 20,
    seed = 500,
)
````

