# # Lab 6. Final report plots for the SIR Petri model
# This script loads saved CSV files and builds summary plots for the report.
#
# ## Project setup

using DrWatson
@quickactivate "lab_06_SIR_petri"

using CSV
using DataFrames
using Plots

function main()
    # ## Load saved results
    df_det = CSV.read(datadir("sir_det.csv"), DataFrame)
    df_stoch = CSV.read(datadir("sir_stoch.csv"), DataFrame)
    df_scan = CSV.read(datadir("sir_scan.csv"), DataFrame)

    # ## Compare deterministic and stochastic infection curves
    n = min(nrow(df_det), nrow(df_stoch))

    p1 = plot(
        df_det.time[1:n],
        df_det.I[1:n],
        label = "Deterministic I",
        xlabel = "Time",
        ylabel = "Infected",
        title = "Deterministic vs stochastic",
        linewidth = 2,
    )
    plot!(
        p1,
        df_stoch.time[1:n],
        df_stoch.I[1:n],
        label = "Stochastic I",
        linewidth = 2,
    )
    savefig(p1, plotsdir("comparison.png"))

    # ## Plot the parameter sensitivity
    p2 = plot(
        df_scan.beta,
        df_scan.peak_I,
        marker = :circle,
        xlabel = "beta",
        ylabel = "Peak I",
        title = "Sensitivity",
        linewidth = 2,
        label = "Peak I",
    )
    savefig(p2, plotsdir("sensitivity.png"))

    println("Report plots saved.")
end

main()
