using ResumableFunctions
using ConcurrentSim
using Distributions
using DataFrames
using Random

function increment!(a::Vector{Int64})
    push!(a, last(a) + 1)
end

function decrement!(a::Vector{Int64})
    push!(a, last(a) - 1)
end

function carryover!(a::Vector{Int64})
    push!(a, last(a))
end

mutable struct SIRPerson
    id::Int64
    status::Symbol
end

mutable struct SIRModel
    sim::ConcurrentSim.Simulation
    beta::Float64
    c::Float64
    gamma::Float64
    ta::Vector{Float64}
    Sa::Vector{Int64}
    Ia::Vector{Int64}
    Ra::Vector{Int64}
    allIndividuals::Vector{SIRPerson}
end

function infection_update!(sim::ConcurrentSim.Simulation, m::SIRModel)
    push!(m.ta, ConcurrentSim.now(sim))
    decrement!(m.Sa)
    increment!(m.Ia)
    carryover!(m.Ra)
    return nothing
end

function recovery_update!(sim::ConcurrentSim.Simulation, m::SIRModel)
    push!(m.ta, ConcurrentSim.now(sim))
    carryover!(m.Sa)
    decrement!(m.Ia)
    increment!(m.Ra)
    return nothing
end

@resumable function live(
    env::ConcurrentSim.Simulation,
    individual::SIRPerson,
    m::SIRModel,
)
    while individual.status == :S
        @yield timeout(env, rand(Exponential(1 / m.c)))

        alter = individual
        while alter === individual
            index = rand(DiscreteUniform(1, length(m.allIndividuals)))
            alter = m.allIndividuals[index]
        end

        if alter.status == :I && rand() < m.beta
            individual.status = :I
            infection_update!(env, m)
        end
    end

    if individual.status == :I
        @yield timeout(env, rand(Exponential(1 / m.gamma)))
        individual.status = :R
        recovery_update!(env, m)
    end
end

function MakeSIRModel(u0, p)
    S, I, R = Int64.(u0)
    beta, c, gamma = Float64.(p)

    S < 0 && throw(ArgumentError("S must be non-negative"))
    I < 0 && throw(ArgumentError("I must be non-negative"))
    R < 0 && throw(ArgumentError("R must be non-negative"))
    !(0.0 <= beta <= 1.0) && throw(ArgumentError("beta must be in [0, 1]"))
    c <= 0.0 && throw(ArgumentError("c must be positive"))
    gamma <= 0.0 && throw(ArgumentError("gamma must be positive"))

    sim = ConcurrentSim.Simulation()
    allIndividuals = SIRPerson[]

    for i in 1:S
        push!(allIndividuals, SIRPerson(i, :S))
    end

    for i in (S + 1):(S + I)
        push!(allIndividuals, SIRPerson(i, :I))
    end

    for i in (S + I + 1):(S + I + R)
        push!(allIndividuals, SIRPerson(i, :R))
    end

    return SIRModel(
        sim,
        beta,
        c,
        gamma,
        Float64[0.0],
        Int64[S],
        Int64[I],
        Int64[R],
        allIndividuals,
    )
end

function activate(m::SIRModel)
    for individual in m.allIndividuals
        @process live(m.sim, individual, m)
    end
    return m
end

function sir_run(m::SIRModel, tf::Float64)
    ConcurrentSim.run(m.sim, tf)
    return m
end

function out(m::SIRModel)
    return DataFrame(t = m.ta, S = m.Sa, I = m.Ia, R = m.Ra)
end
