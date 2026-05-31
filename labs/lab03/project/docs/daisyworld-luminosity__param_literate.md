```@meta
EditURL = "../scripts/daisyworld-luminosity__param_literate.jl"
```

# Динамика модели Daisyworld с параметрами

## Введение

Построим комплексный график изменения числа маргариток, температуры
и солнечной светимости с разными параметрами модели.

Используем сценарий `:ramp`:
- Шаги 0--200: $L = 1.0$ (постоянная)
- Шаги 200--400: $L$ растёт на $+0.005$ каждый шаг
- Шаги 400--500: $L$ постоянная
- Шаги 500--750: $L$ убывает на $-0.0025$ каждый шаг
- Шаги 750--1000: $L$ постоянная

## Варьируемые параметры

| Параметр | Значения | Смысл |
|----------|----------|-------|
| `max_age` | 25, 40 | максимальный возраст маргаритки |
| `init_white` | 0.2, 0.8 | начальная доля белых маргариток |

Итого $2 \times 2 = 4$ комбинации.

## Ожидаемые эффекты

- При `max_age = 40` маргаритки живут дольше и лучше справляются
  с регуляцией температуры при изменении светимости.
- При `init_white = 0.8` начальная температура ниже; при росте
  светимости белые маргаритки дольше компенсируют перегрев,
  но после их вымирания температура резко возрастает.

## Подключение пакетов

````@example daisyworld-luminosity__param_literate
using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
using CairoMakie
````

## Загрузка модели

````@example daisyworld-luminosity__param_literate
include(srcdir("daisyworld.jl"))
````

## Функции подсчёта агентов

````@example daisyworld-luminosity__param_literate
black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]
````

## Параметры эксперимента

````@example daisyworld-luminosity__param_literate
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
    :scenario => :ramp,
    :seed => 165,
)
````

## Создание списка комбинаций

````@example daisyworld-luminosity__param_literate
params_list = dict_list(param_dict)
````

## Цикл по комбинациям

Для каждой комбинации прогоняем модель на 1000 шагов
и строим трёхпанельный график: число маргариток, температура, светимость.

````@example daisyworld-luminosity__param_literate
for params in params_list
    model = daisyworld(;params...)
    temperature(model) = StatsBase.mean(model.temperature)
    mdata = [temperature, :solar_luminosity]
    agent_df, model_df = run!(model, 1000; adata = adata, mdata = mdata)
    figure = CairoMakie.Figure(size = (600, 600));
    ax1 = figure[1, 1] = Axis(figure, ylabel = "daisy count")
    blackl = lines!(ax1, agent_df[!, :time], agent_df[!, :count_black], color = :red)
    whitel = lines!(ax1, agent_df[!, :time], agent_df[!, :count_white], color = :blue)
    figure[1, 2] = Legend(figure, [blackl, whitel], ["black", "white"])
    ax2 = figure[2, 1] = Axis(figure, ylabel = "temperature")
    ax3 = figure[3, 1] = Axis(figure, xlabel = "tick", ylabel = "luminosity")
    lines!(ax2, model_df[!, :time], model_df[!, :temperature], color = :red)
    lines!(ax3, model_df[!, :time], model_df[!, :solar_luminosity], color = :red)
    for ax in (ax1, ax2); ax.xticklabelsvisible = false; end
    plt_name = savename("daisy-luminosity", params) * ".png"
    #jl save(plotsdir(plt_name), figure)
end
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

