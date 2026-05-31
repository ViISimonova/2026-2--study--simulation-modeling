# # Lab 6. Animation of the deterministic SIR dynamics
# This script creates a GIF animation showing the evolution of S, I and R.
#
# ## Project setup

using DrWatson
@quickactivate "lab_06_SIR_petri"

include(srcdir("SIRPetri.jl"))
using DataFrames
using Plots

function main()
    # ## Model parameters
    beta = 0.3
    gamma = 0.1
    tmax = 100.0

    # ## Deterministic trajectory for the animation
    net, u0, _ = SIRPetri.build_sir_network(beta, gamma)
    df = SIRPetri.simulate_deterministic(net, u0, (0.0, tmax); saveat = 0.2, rates = [beta, gamma])

    # ## Build the animation
    anim = @animate for i in 1:nrow(df)
        bar(
            ["S", "I", "R"],
            [df.S[i], df.I[i], df.R[i]];
            ylim = (0, 1000),
            legend = false,
            xlabel = "State",
            ylabel = "Population",
            title = "t = $(round(df.time[i], digits = 1))",
        )
    end

    # ## Save the GIF file
    gif(anim, plotsdir("sir_animation.gif"), fps = 10)
    println("Animation saved.")
end

main()
