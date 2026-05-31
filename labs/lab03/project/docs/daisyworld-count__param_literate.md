```@meta
EditURL = "../scripts/daisyworld-count__param_literate.jl"
```

# Динамика числа маргариток с параметрами

## Введение

Построим график изменения числа маргариток в зависимости от модельного
времени с разными параметрами модели.

## Варьируемые параметры

| Параметр | Значения | Смысл |
|----------|----------|-------|
| `max_age` | 25, 40 | максимальный возраст маргаритки |
| `init_white` | 0.2, 0.8 | начальная доля белых маргариток |

Итого $2 \times 2 = 4$ комбинации.

## Ожидаемые эффекты

- При `max_age = 40` маргаритки живут дольше --- колебания сглаживаются,
  популяция стабильнее.
- При `init_white = 0.8` белых маргариток изначально в 4 раза больше
  чёрных --- начальная температура ниже, динамика выхода на равновесие
  отличается от базового случая.

## Подключение пакетов

````@example daisyworld-count__param_literate
using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
using CairoMakie
````

## Загрузка модели

````@example daisyworld-count__param_literate
include(srcdir("daisyworld.jl"))
````

## Функции подсчёта агентов

````@example daisyworld-count__param_literate
black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]
````

## Параметры эксперимента

````@example daisyworld-count__param_literate
param_dict = Dict(
    :griddims => (30, 30),
    :max_age => [25, 40],
    :init_white => [0.2, 0.8],
    :init_black => 0.2,
    :albedo_white => 0.75,
    :albedo_black => 0.25,
    :surface_albedo => 0.4,
    :solar_change => 0.005,
    :solar_luminosity => 1.0,
    :scenario => :default,
    :seed => 165,
)
````

## Создание списка комбинаций

````@example daisyworld-count__param_literate
params_list = dict_list(param_dict)
````

## Цикл по комбинациям

Для каждой комбинации прогоняем модель на 1000 шагов
и строим график динамики числа маргариток.

````@example daisyworld-count__param_literate
for params in params_list
    model = daisyworld(;params...)
    agent_df, model_df = run!(model, 1000; adata)
    figure = Figure(size = (600, 400));
    ax = figure[1, 1] = Axis(figure, xlabel = "tick", ylabel = "daisy count")
    blackl = lines!(ax, agent_df[!, :time], agent_df[!, :count_black], color = :black)
    whitel = lines!(ax, agent_df[!, :time], agent_df[!, :count_white], color = :orange)
    Legend(figure[1, 2], [blackl, whitel], ["black", "white"], labelsize = 12)
    plt_name = savename("daisy-count", params) * ".png"
    #jl save(plotsdir(plt_name), figure)
end
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

