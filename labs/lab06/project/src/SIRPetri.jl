module SIRPetri

using AlgebraicPetri
using Catlab.Graphics
using DataFrames
using OrdinaryDiffEq
using Plots
using Random

export build_sir_network
export sir_ode
export simulate_deterministic
export simulate_stochastic
export plot_sir
export to_graphviz_sir

"""
    build_sir_network(beta=0.3, gamma=0.1)

Create the labelled Petri net for the SIR model and return
`(net, u0, states)`.
"""
function build_sir_network(beta::Real = 0.3, gamma::Real = 0.1)
    _ = (beta, gamma)

    states = [:S, :I, :R]
    net = LabelledPetriNet(
        states,
        :infection => ([:S, :I] => [:I, :I]),
        :recovery => ([:I] => [:R]),
    )

    u0 = [990.0, 10.0, 0.0]
    return net, u0, states
end

"""
    sir_ode(net, rates=[0.3, 0.1])

Return the right-hand side for the deterministic SIR model.
"""
function sir_ode(net, rates::AbstractVector{<:Real} = [0.3, 0.1])
    _ = net

    function f!(du, u, p, t)
        _ = (p, t)

        s, i, r = u
        _ = r
        beta, gamma = rates

        infection_rate = beta * s * i
        recovery_rate = gamma * i

        du[1] = -infection_rate
        du[2] = infection_rate - recovery_rate
        du[3] = recovery_rate
        return nothing
    end

    return f!
end

"""
    simulate_deterministic(net, u0, tspan; saveat=0.1, rates=[0.3, 0.1])

Run the deterministic simulation and return a `DataFrame`
with columns `time`, `S`, `I`, `R`.
"""
function simulate_deterministic(net, u0, tspan; saveat = 0.1, rates = [0.3, 0.1])
    f = sir_ode(net, rates)
    prob = ODEProblem(f, u0, tspan)
    sol = solve(prob, Tsit5(), saveat = saveat)

    df = DataFrame(time = sol.t)
    df.S = sol[1, :]
    df.I = sol[2, :]
    df.R = sol[3, :]
    return df
end

"""
    simulate_stochastic(net, u0, tspan; rates=[0.3, 0.1], rng=Random.GLOBAL_RNG)

Run a Gillespie SSA simulation and return a `DataFrame`
with columns `time`, `S`, `I`, `R`.
"""
function simulate_stochastic(net, u0, tspan; rates = [0.3, 0.1], rng = Random.GLOBAL_RNG)
    _ = net

    u = Int.(round.(u0))
    t = Float64(tspan[1])
    tmax = Float64(tspan[2])

    times = Float64[t]
    states = Vector{Vector{Int}}()
    push!(states, copy(u))

    beta, gamma = rates

    while t < tmax
        s, i, r = u
        _ = r

        a_inf = beta * s * i
        a_rec = gamma * i
        a0 = a_inf + a_rec

        if a0 <= 0
            break
        end

        dt = -log(rand(rng)) / a0
        event_draw = rand(rng) * a0

        if event_draw < a_inf
            u[1] -= 1
            u[2] += 1
        else
            u[2] -= 1
            u[3] += 1
        end

        t += dt

        if t <= tmax
            push!(times, t)
            push!(states, copy(u))
        end
    end

    df = DataFrame(time = times)
    df.S = [state[1] for state in states]
    df.I = [state[2] for state in states]
    df.R = [state[3] for state in states]
    return df
end

"""
    plot_sir(df)

Plot `S(t)`, `I(t)` and `R(t)` from a `DataFrame`.
"""
function plot_sir(df::DataFrame)
    return plot(
        df.time,
        Matrix(df[:, [:S, :I, :R]]),
        label = ["S" "I" "R"],
        xlabel = "Time",
        ylabel = "Population",
        linewidth = 2,
        title = "SIR dynamics",
    )
end

"""
    to_graphviz_sir(net)

Return the Graphviz object for the SIR Petri net.
"""
function to_graphviz_sir(net)
    return to_graphviz(net, prog = "dot")
end

end
