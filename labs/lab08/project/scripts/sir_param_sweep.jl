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
base_p = [0.05, 10.0, 0.25]

betas = [0.03, 0.05, 0.07]
cs = [5.0, 10.0, 15.0]
gammas = [0.15, 0.25, 0.35]

function run_sir_case(u0, p, tmax; seed = 1234)
    Random.seed!(seed)
    model = MakeSIRModel(u0, p)
    activate(model)
    sir_run(model, tmax)
    return out(model)
end

function metrics_row(parameter, value, data)
    peak_index = argmax(data.I)
    total_population = data.S[end] + data.I[end] + data.R[end]

    return (
        parameter = parameter,
        parameter_value = Float64(value),
        peak_I = Int64(data.I[peak_index]),
        peak_time = Float64(data.t[peak_index]),
        final_R = Int64(data.R[end]),
        final_R_share = Float64(data.R[end] / total_population),
    )
end

function save_sweep_plot(cases, plot_title, output_path)
    sweep_plot = plot(
        layout = (3, 1),
        size = (900, 900),
        title = plot_title,
        legend = :right,
    )

    for (label, data) in cases
        plot!(sweep_plot, data.t, data.S, subplot = 1, label = label, ylabel = "S")
        plot!(sweep_plot, data.t, data.I, subplot = 2, label = label, ylabel = "I")
        plot!(
            sweep_plot,
            data.t,
            data.R,
            subplot = 3,
            label = label,
            xlabel = "Time",
            ylabel = "R",
        )
    end

    savefig(sweep_plot, output_path)
    return output_path
end

function run_parameter_sweep(parameter, values, base_p, u0, tmax)
    cases = Pair{String,DataFrame}[]
    rows = NamedTuple[]

    for value in values
        p = copy(base_p)
        if parameter == "beta"
            p[1] = value
        elseif parameter == "c"
            p[2] = value
        elseif parameter == "gamma"
            p[3] = value
        else
            throw(ArgumentError("Unknown parameter: $parameter"))
        end

        data = run_sir_case(u0, p, tmax)
        push!(cases, "$(parameter)=$(value)" => data)
        push!(rows, metrics_row(parameter, value, data))
    end

    return cases, rows
end

mkpath(plotsdir())
mkpath(datadir("sims"))

metrics = DataFrame(
    parameter = String[],
    parameter_value = Float64[],
    peak_I = Int64[],
    peak_time = Float64[],
    final_R = Int64[],
    final_R_share = Float64[],
)

beta_cases, beta_rows = run_parameter_sweep("beta", betas, base_p, u0, tmax)
c_cases, c_rows = run_parameter_sweep("c", cs, base_p, u0, tmax)
gamma_cases, gamma_rows = run_parameter_sweep("gamma", gammas, base_p, u0, tmax)

append!(metrics, DataFrame(beta_rows))
append!(metrics, DataFrame(c_rows))
append!(metrics, DataFrame(gamma_rows))

beta_plot_path = plotsdir("sir_beta_sweep.png")
c_plot_path = plotsdir("sir_c_sweep.png")
gamma_plot_path = plotsdir("sir_gamma_sweep.png")

save_sweep_plot(beta_cases, "SIR sensitivity to beta", beta_plot_path)
save_sweep_plot(c_cases, "SIR sensitivity to c", c_plot_path)
save_sweep_plot(gamma_cases, "SIR sensitivity to gamma", gamma_plot_path)

metrics_path = datadir("sims", "sir_param_sweep_metrics.csv")
CSV.write(metrics_path, metrics)

println("Saved plot: ", beta_plot_path)
println("Saved plot: ", c_plot_path)
println("Saved plot: ", gamma_plot_path)
println("Saved table: ", metrics_path)

metrics
