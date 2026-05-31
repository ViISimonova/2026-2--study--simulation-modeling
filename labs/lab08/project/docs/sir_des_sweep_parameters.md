```@meta
EditURL = "../scripts/sir_des_sweep_parameters_literate.jl"
```

# SIR parameter sweep

This literate script runs the discrete-event SIR model for several parameter
sets. It saves full trajectories, summary metrics, and comparison plots.

````julia
using DrWatson

@quickactivate "lab08_models"

include(srcdir("sir_model.jl"))

ENV["GKSwstype"] = "100"

using CSV
using DataFrames
using Random
using StatsPlots
````

## Parameter set

````julia
tmax = 40.0
u0 = [990, 10, 0]

sweep_parameters = DataFrame(
    case = [
        "baseline",
        "beta_low",
        "beta_high",
        "contacts_low",
        "contacts_high",
        "recovery_slow",
        "recovery_fast",
    ],
    beta = [0.05, 0.03, 0.07, 0.05, 0.05, 0.05, 0.05],
    c = [10.0, 10.0, 10.0, 5.0, 15.0, 10.0, 10.0],
    gamma = [0.25, 0.25, 0.25, 0.25, 0.25, 0.15, 0.35],
)
````

```@raw html
<div><div style = "float: left;"><span>7×4 DataFrame</span></div><div style = "clear: both;"></div></div><div class = "data-frame" style = "overflow-x: scroll;"><table class = "data-frame" style = "margin-bottom: 6px;"><thead><tr class = "columnLabelRow"><th class = "stubheadLabel" style = "font-weight: bold; text-align: right;">Row</th><th style = "text-align: left;">case</th><th style = "text-align: left;">beta</th><th style = "text-align: left;">c</th><th style = "text-align: left;">gamma</th></tr><tr class = "columnLabelRow"><th class = "stubheadLabel" style = "font-weight: bold; text-align: right;"></th><th title = "String" style = "text-align: left;">String</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th></tr></thead><tbody><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">1</td><td style = "text-align: left;">baseline</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">2</td><td style = "text-align: left;">beta_low</td><td style = "text-align: right;">0.03</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">3</td><td style = "text-align: left;">beta_high</td><td style = "text-align: right;">0.07</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">4</td><td style = "text-align: left;">contacts_low</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">5.0</td><td style = "text-align: right;">0.25</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">5</td><td style = "text-align: left;">contacts_high</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">15.0</td><td style = "text-align: right;">0.25</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">6</td><td style = "text-align: left;">recovery_slow</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.15</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">7</td><td style = "text-align: left;">recovery_fast</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.35</td></tr></tbody></table></div>
```

## Simulation helpers

````julia
function run_sweep_case(case_name, beta, c, gamma, u0, tmax; seed = 1234)
    Random.seed!(seed)
    model = MakeSIRModel(u0, [beta, c, gamma])
    activate(model)
    sir_run(model, tmax)

    data = out(model)
    insertcols!(
        data,
        1,
        :case => fill(case_name, nrow(data)),
        :beta => fill(beta, nrow(data)),
        :c => fill(c, nrow(data)),
        :gamma => fill(gamma, nrow(data)),
    )

    return data
end

function sweep_metrics(data)
    peak_index = argmax(data.I)
    total_population = data.S[end] + data.I[end] + data.R[end]

    return (
        case = data.case[1],
        beta = Float64(data.beta[1]),
        c = Float64(data.c[1]),
        gamma = Float64(data.gamma[1]),
        peak_I = Int64(data.I[peak_index]),
        peak_time = Float64(data.t[peak_index]),
        final_R = Int64(data.R[end]),
        final_R_share = Float64(data.R[end] / total_population),
    )
end
````

````
sweep_metrics (generic function with 1 method)
````

## Plot helpers

````julia
function infected_sweep_plot(timeseries)
    p = plot(
        xlabel = "Time",
        ylabel = "Infected",
        title = "SIR parameter sweep: infected population",
        legend = :outerright,
        size = (1000, 600),
    )

    for group in groupby(timeseries, :case)
        plot!(p, group.t, group.I, label = group.case[1])
    end

    return p
end

function final_size_sweep_plot(metrics)
    return bar(
        metrics.case,
        metrics.final_R_share,
        label = false,
        xlabel = "Case",
        ylabel = "Final recovered share",
        title = "SIR parameter sweep: final epidemic size",
        xrotation = 45,
        size = (1000, 600),
    )
end
````

````
final_size_sweep_plot (generic function with 1 method)
````

## Run simulations

````julia
mkpath(plotsdir())
mkpath(datadir("sims"))

timeseries = DataFrame(
    case = String[],
    beta = Float64[],
    c = Float64[],
    gamma = Float64[],
    t = Float64[],
    S = Int64[],
    I = Int64[],
    R = Int64[],
)
metrics_rows = NamedTuple[]

for row in eachrow(sweep_parameters)
    data = run_sweep_case(row.case, row.beta, row.c, row.gamma, u0, tmax)
    append!(timeseries, data)
    push!(metrics_rows, sweep_metrics(data))
end

metrics = DataFrame(metrics_rows)
````

```@raw html
<div><div style = "float: left;"><span>7×8 DataFrame</span></div><div style = "clear: both;"></div></div><div class = "data-frame" style = "overflow-x: scroll;"><table class = "data-frame" style = "margin-bottom: 6px;"><thead><tr class = "columnLabelRow"><th class = "stubheadLabel" style = "font-weight: bold; text-align: right;">Row</th><th style = "text-align: left;">case</th><th style = "text-align: left;">beta</th><th style = "text-align: left;">c</th><th style = "text-align: left;">gamma</th><th style = "text-align: left;">peak_I</th><th style = "text-align: left;">peak_time</th><th style = "text-align: left;">final_R</th><th style = "text-align: left;">final_R_share</th></tr><tr class = "columnLabelRow"><th class = "stubheadLabel" style = "font-weight: bold; text-align: right;"></th><th title = "String" style = "text-align: left;">String</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Int64" style = "text-align: left;">Int64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Int64" style = "text-align: left;">Int64</th><th title = "Float64" style = "text-align: left;">Float64</th></tr></thead><tbody><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">1</td><td style = "text-align: left;">baseline</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">174</td><td style = "text-align: right;">17.8722</td><td style = "text-align: right;">751</td><td style = "text-align: right;">0.751</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">2</td><td style = "text-align: left;">beta_low</td><td style = "text-align: right;">0.03</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">24</td><td style = "text-align: right;">37.8662</td><td style = "text-align: right;">116</td><td style = "text-align: right;">0.116</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">3</td><td style = "text-align: left;">beta_high</td><td style = "text-align: right;">0.07</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">264</td><td style = "text-align: right;">12.2485</td><td style = "text-align: right;">924</td><td style = "text-align: right;">0.924</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">4</td><td style = "text-align: left;">contacts_low</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">5.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">21</td><td style = "text-align: right;">7.16314</td><td style = "text-align: right;">82</td><td style = "text-align: right;">0.082</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">5</td><td style = "text-align: left;">contacts_high</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">15.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">293</td><td style = "text-align: right;">8.24357</td><td style = "text-align: right;">924</td><td style = "text-align: right;">0.924</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">6</td><td style = "text-align: left;">recovery_slow</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.15</td><td style = "text-align: right;">376</td><td style = "text-align: right;">14.5966</td><td style = "text-align: right;">941</td><td style = "text-align: right;">0.941</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">7</td><td style = "text-align: left;">recovery_fast</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.35</td><td style = "text-align: right;">109</td><td style = "text-align: right;">20.5455</td><td style = "text-align: right;">576</td><td style = "text-align: right;">0.576</td></tr></tbody></table></div>
```

## Save outputs

````julia
timeseries_path = datadir("sims", "sir_des_sweep_parameters_timeseries.csv")
metrics_path = datadir("sims", "sir_des_sweep_parameters_metrics.csv")
infected_plot_path = plotsdir("sir_des_sweep_parameters_infected.png")
final_size_plot_path = plotsdir("sir_des_sweep_parameters_final_size.png")

CSV.write(timeseries_path, timeseries)
CSV.write(metrics_path, metrics)
savefig(infected_sweep_plot(timeseries), infected_plot_path)
savefig(final_size_sweep_plot(metrics), final_size_plot_path)

println("Saved table: ", timeseries_path)
println("Saved table: ", metrics_path)
println("Saved plot: ", infected_plot_path)
println("Saved plot: ", final_size_plot_path)

metrics
````

```@raw html
<div><div style = "float: left;"><span>7×8 DataFrame</span></div><div style = "clear: both;"></div></div><div class = "data-frame" style = "overflow-x: scroll;"><table class = "data-frame" style = "margin-bottom: 6px;"><thead><tr class = "columnLabelRow"><th class = "stubheadLabel" style = "font-weight: bold; text-align: right;">Row</th><th style = "text-align: left;">case</th><th style = "text-align: left;">beta</th><th style = "text-align: left;">c</th><th style = "text-align: left;">gamma</th><th style = "text-align: left;">peak_I</th><th style = "text-align: left;">peak_time</th><th style = "text-align: left;">final_R</th><th style = "text-align: left;">final_R_share</th></tr><tr class = "columnLabelRow"><th class = "stubheadLabel" style = "font-weight: bold; text-align: right;"></th><th title = "String" style = "text-align: left;">String</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Int64" style = "text-align: left;">Int64</th><th title = "Float64" style = "text-align: left;">Float64</th><th title = "Int64" style = "text-align: left;">Int64</th><th title = "Float64" style = "text-align: left;">Float64</th></tr></thead><tbody><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">1</td><td style = "text-align: left;">baseline</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">174</td><td style = "text-align: right;">17.8722</td><td style = "text-align: right;">751</td><td style = "text-align: right;">0.751</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">2</td><td style = "text-align: left;">beta_low</td><td style = "text-align: right;">0.03</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">24</td><td style = "text-align: right;">37.8662</td><td style = "text-align: right;">116</td><td style = "text-align: right;">0.116</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">3</td><td style = "text-align: left;">beta_high</td><td style = "text-align: right;">0.07</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">264</td><td style = "text-align: right;">12.2485</td><td style = "text-align: right;">924</td><td style = "text-align: right;">0.924</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">4</td><td style = "text-align: left;">contacts_low</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">5.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">21</td><td style = "text-align: right;">7.16314</td><td style = "text-align: right;">82</td><td style = "text-align: right;">0.082</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">5</td><td style = "text-align: left;">contacts_high</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">15.0</td><td style = "text-align: right;">0.25</td><td style = "text-align: right;">293</td><td style = "text-align: right;">8.24357</td><td style = "text-align: right;">924</td><td style = "text-align: right;">0.924</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">6</td><td style = "text-align: left;">recovery_slow</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.15</td><td style = "text-align: right;">376</td><td style = "text-align: right;">14.5966</td><td style = "text-align: right;">941</td><td style = "text-align: right;">0.941</td></tr><tr class = "dataRow"><td class = "rowLabel" style = "font-weight: bold; text-align: right;">7</td><td style = "text-align: left;">recovery_fast</td><td style = "text-align: right;">0.05</td><td style = "text-align: right;">10.0</td><td style = "text-align: right;">0.35</td><td style = "text-align: right;">109</td><td style = "text-align: right;">20.5455</td><td style = "text-align: right;">576</td><td style = "text-align: right;">0.576</td></tr></tbody></table></div>
```

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*
