# # ЛР 5. Параметрическое исследование
# В этом скрипте выполняется серия запусков для разных значений
# числа философов, времени моделирования и начального зерна генератора.
#
# ## Подключение проекта и зависимостей

using DrWatson
@quickactivate "lab05_Petry"

include(srcdir("DiningPhilosophers.jl"))
using DataFrames, CSV, Plots, Random, Statistics

function main()
    # ## Наборы параметров
    N_VALUES = [3, 5, 7]
    TMAX_VALUES = [30.0, 50.0, 80.0]
    SEEDS = [123, 124, 125]

    results = DataFrame(
        network = String[],
        N = Int[],
        tmax = Float64[],
        seed = Int[],
        deadlock = Bool[],
        events = Int[],
        final_hungry = Float64[],
        final_eat = Float64[],
    )

    # ## Серия запусков
    for N in N_VALUES
        for tmax in TMAX_VALUES
            for seed in SEEDS
                rng_classic = MersenneTwister(seed)
                net_classic, u0_classic, _ = DiningPhilosophers.build_classical_network(N)
                df_classic = DiningPhilosophers.simulate_stochastic(net_classic, u0_classic, tmax; rng = rng_classic)
                dead_classic = DiningPhilosophers.detect_deadlock(df_classic, net_classic)
                hungry_classic = sum(df_classic[end, "Hungry_$i"] for i = 1:N)
                eat_classic = sum(df_classic[end, "Eat_$i"] for i = 1:N)
                push!(
                    results,
                    ("classic", N, tmax, seed, dead_classic, nrow(df_classic), hungry_classic, eat_classic),
                )

                rng_arb = MersenneTwister(seed)
                net_arb, u0_arb, _ = DiningPhilosophers.build_arbiter_network(N)
                df_arb = DiningPhilosophers.simulate_stochastic(net_arb, u0_arb, tmax; rng = rng_arb)
                dead_arb = DiningPhilosophers.detect_deadlock(df_arb, net_arb)
                hungry_arb = sum(df_arb[end, "Hungry_$i"] for i = 1:N)
                eat_arb = sum(df_arb[end, "Eat_$i"] for i = 1:N)
                push!(
                    results,
                    ("arbiter", N, tmax, seed, dead_arb, nrow(df_arb), hungry_arb, eat_arb),
                )
            end
        end
    end

    # ## Сохранение таблицы результатов
    CSV.write(datadir("dining_params.csv"), results)

    # ## Агрегация и построение графика
    summary = combine(
        groupby(results, [:network, :N, :tmax]),
        :deadlock => mean => :deadlock_rate,
        :events => mean => :mean_events,
        :final_eat => mean => :mean_final_eat,
    )

    p1 = plot(
        title = "Доля deadlock по параметрам",
        xlabel = "N",
        ylabel = "Deadlock rate",
    )
    for network in ["classic", "arbiter"]
        for tmax in TMAX_VALUES
            sub = summary[(summary.network .== network) .& (summary.tmax .== tmax), :]
            sort!(sub, :N)
            plot!(
                p1,
                sub.N,
                sub.deadlock_rate,
                marker = :circle,
                label = "$network, tmax = $tmax",
            )
        end
    end

    savefig(p1, plotsdir("dining_params.png"))
    println("Параметрический отчёт сохранён в data/dining_params.csv и plots/dining_params.png")
end

main()
