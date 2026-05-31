```@meta
EditURL = "../scripts/dining_philosophers_animation.jl"
```

````julia
using DrWatson
@quickactivate "lab05_Petry"

include(srcdir("DiningPhilosophers.jl"))
using Plots, Random

function main()
    N = 3
    tmax = 30.0
    net, u0, names = DiningPhilosophers.build_classical_network(N)

    Random.seed!(123)
    df = DiningPhilosophers.simulate_stochastic(net, u0, tmax)

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
````

````
Could not create decoration from factory! Running with no decorations.
[ Info: Saved animation to /home/daidrisov/imit-model/2026-1--study--simulation-modeling/labs/lab05/lab05_Petry/plots/philosophers_simulation.gif
Анимация сохранена в plots/philosophers_simulation.gif

````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

