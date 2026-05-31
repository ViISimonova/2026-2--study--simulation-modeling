```@meta
EditURL = "../scripts/sirpetri_run.jl"
```

````julia
using DrWatson
@quickactivate "lab_06_SIR_petri"

include(srcdir("SIRPetri.jl"))
using .SIRPetri
using CSV
using Plots
using Random

function main()
    beta = 0.3
    gamma = 0.1
    tmax = 100.0

    net, u0, _ = build_sir_network(beta, gamma)

    df_det = simulate_deterministic(
        net,
        u0,
        (0.0, tmax);
        saveat = 0.5,
        rates = [beta, gamma],
    )
    CSV.write(datadir("sir_det.csv"), df_det)

    Random.seed!(123)
    df_stoch = simulate_stochastic(net, u0, (0.0, tmax); rates = [beta, gamma])
    CSV.write(datadir("sir_stoch.csv"), df_stoch)

    p_det = plot_sir(df_det)
    savefig(p_det, plotsdir("sir_det_dynamics.png"))

    p_stoch = plot_sir(df_stoch)
    savefig(p_stoch, plotsdir("sir_stoch_dynamics.png"))

    println("Baseline SIR runs completed.")
end

main()
````

````
Could not create decoration from factory! Running with no decorations.
Baseline SIR runs completed.

````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*
