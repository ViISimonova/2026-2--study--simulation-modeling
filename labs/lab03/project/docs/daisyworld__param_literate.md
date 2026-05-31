```@meta
EditURL = "../scripts/daisyworld__param_literate.jl"
```

# Базовая визуализация Daisyworld с параметрами

## Введение

Расширим базовую визуализацию за счёт перебора параметров модели.
Используем функцию `dict_list` из DrWatson, которая генерирует
все комбинации из словаря параметров.

## Варьируемые параметры

| Параметр | Значения | Смысл |
|----------|----------|-------|
| `max_age` | 25, 40 | максимальный возраст маргаритки |
| `init_white` | 0.2, 0.8 | начальная доля белых маргариток |

Остальные параметры фиксированы. Итого $2 \times 2 = 4$ комбинации.

## Ожидаемые эффекты

- **`max_age = 40`** --- маргаритки живут дольше, популяция стабильнее,
  колебания менее выражены.
- **`init_white = 0.8`** --- начальная температура ниже, потому что
  белые маргаритки (альбедо $\alpha = 0.75$) отражают больше света.
  Система приходит к другому равновесию.

## Именование файлов

DrWatson автоматически генерирует уникальные имена файлов
через `savename()`, включая значения параметров в имя.

## Подключение пакетов

````@example daisyworld__param_literate
using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
using CairoMakie
````

## Загрузка модели

````@example daisyworld__param_literate
include(srcdir("daisyworld.jl"))
````

## Параметры эксперимента

````@example daisyworld__param_literate
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

`dict_list` берёт словарь, где некоторые значения --- массивы,
и возвращает вектор словарей со всеми комбинациями.

````@example daisyworld__param_literate
params_list = dict_list(param_dict)
````

## Цикл по комбинациям параметров

Для каждой комбинации создаём модель и строим тепловые карты
на шагах 0, 5 и 40.

````@example daisyworld__param_literate
for params in params_list

    model = daisyworld(;params...)

    daisycolor(a::Daisy) = a.breed

    plotkwargs = (
        agent_color=daisycolor,
        agent_size = 20,
        agent_marker = '*',
        heatarray = :temperature,
        heatkwargs = (colorrange = (-20, 60),),
    )
````

### Начальное состояние

````@example daisyworld__param_literate
    plt1, _ = abmplot(model; plotkwargs...)
````

### После 5 шагов

````@example daisyworld__param_literate
    step!(model, 5)
    plt2, _ = abmplot(model; heatarray = model.temperature,
        plotkwargs...)
````

### После 40 шагов

````@example daisyworld__param_literate
    step!(model, 40)
    plt3, _ = abmplot(model; heatarray = model.temperature,
        plotkwargs...)
````

### Сохранение с уникальными именами

````@example daisyworld__param_literate
    plt1_name = savename("daisyworld",params) * "_step01" * ".png"
    plt2_name = savename("daisyworld",params) * "_step04" * ".png"
    plt3_name = savename("daisyworld",params) * "_step40" * ".png"

    #jl save(plotsdir(plt1_name), plt1)
    #jl save(plotsdir(plt2_name), plt2)
    #jl save(plotsdir(plt3_name), plt3)
end
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

