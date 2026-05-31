using DrWatson

@quickactivate "lab08_models"

include(srcdir("sir_model.jl"))

ENV["GKSwstype"] = "100"

using CSV
using DataFrames
using Random
using StatsPlots

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
