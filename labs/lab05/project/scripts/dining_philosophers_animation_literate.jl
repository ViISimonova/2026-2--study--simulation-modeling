# # ЛР 5. Анимация сети Петри
# В этом скрипте строится GIF-анимация изменения маркировки
# для классической сети Петри.
#
# ## Подключение проекта и зависимостей

using DrWatson
@quickactivate "lab05_Petry"

include(srcdir("DiningPhilosophers.jl"))
using Plots, Random

function main()
    # ## Параметры моделирования
    N = 3
    tmax = 30.0
    net, u0, names = DiningPhilosophers.build_classical_network(N)

    # ## Стохастическая симуляция
    Random.seed!(123)
    df = DiningPhilosophers.simulate_stochastic(net, u0, tmax)

    # ## Построение анимации
    anim = @animate for row in eachrow(df)
        u = [row[col] for col in propertynames(row) if col != :time]
        bar(
            1:length(u),
            u,
            legend = false,
            ylims = (0, maximum(u0) + 1),
            xlabel = "Позиция",
            ylabel = "Фишки",
            title = "Время = $(round(row.time, digits = 2))",
        )
        xticks!(1:length(u), string.(names), rotation = 45)
    end

    gif(anim, plotsdir("philosophers_simulation.gif"), fps = 2)
    println("Анимация сохранена в plots/philosophers_simulation.gif")
end

main()
