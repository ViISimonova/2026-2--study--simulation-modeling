using DrWatson
@quickactivate "lab_06_SIR_petri"

include(srcdir("SIRPetri.jl"))
using CSV
using DataFrames
using Plots

function main()
    beta_range = 0.1:0.05:0.8
    gamma_fixed = 0.1
    tmax = 100.0

    results = DataFrame(
        beta = Float64[],
        peak_I = Float64[],
        final_R = Float64[],
    )

    for beta in beta_range
        net, u0, _ = SIRPetri.build_sir_network(beta, gamma_fixed)
        df = SIRPetri.simulate_deterministic(
            net,
            u0,
            (0.0, tmax);
            saveat = 0.5,
            rates = [beta, gamma_fixed],
        )

        push!(
            results,
            (
                beta = Float64(beta),
                peak_I = maximum(df.I),
                final_R = df.R[end],
            ),
        )
    end

    CSV.write(datadir("sir_scan.csv"), results)

    p = plot(
        results.beta,
        hcat(results.peak_I, results.final_R),
        label = ["Peak I" "Final R"],
        marker = :circle,
        xlabel = "beta",
        ylabel = "Population",
        title = "Sensitivity to infection rate",
    )
    savefig(p, plotsdir("sir_scan.png"))

    println("Parameter scan completed.")
end

main()
