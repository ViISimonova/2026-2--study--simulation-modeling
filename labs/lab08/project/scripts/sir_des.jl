using DrWatson

@quickactivate "lab08_models"

include(srcdir("sir_model.jl"))

ENV["GKSwstype"] = "100"

using CSV
using Random
using StatsPlots

tmax = 40.0
u0 = [990, 10, 0]
p = [0.05, 10.0, 0.25]

Random.seed!(1234)

des_model = MakeSIRModel(u0, p)
activate(des_model)
sir_run(des_model, tmax)
data_des = out(des_model)

mkpath(plotsdir())
mkpath(datadir("sims"))

sir_plot = plot(
    data_des.t,
    data_des.S,
    label = "S",
    xlabel = "Time",
    ylabel = "Population",
    title = "Discrete-event SIR model",
    legend = :right,
)
plot!(sir_plot, data_des.t, data_des.I, label = "I")
plot!(sir_plot, data_des.t, data_des.R, label = "R")

sir_plot_path = plotsdir("sir_des.png")
savefig(sir_plot, sir_plot_path)

sir_data_path = datadir(
    "sims",
    "sir_$(u0[1])_$(u0[2])_$(p[1])_$(p[2])_$(p[3]).csv",
)
CSV.write(sir_data_path, data_des)

println("Saved plot: ", sir_plot_path)
println("Saved table: ", sir_data_path)

data_des
