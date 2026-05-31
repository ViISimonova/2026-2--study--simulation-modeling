```@meta
EditURL = "../scripts/daisyworld-count_literate.jl"
```

# Динамика числа маргариток в модели Daisyworld

## Введение

Построим график изменения числа чёрных и белых маргариток
в зависимости от модельного времени.

Модель Daisyworld демонстрирует **саморегуляцию**: популяции
чёрных и белых маргариток конкурируют за пространство на сетке,
и их численность колеблется вокруг динамического равновесия.

## Механизм колебаний

- Когда чёрных маргариток много --- температура растёт
  (низкое альбедо $\alpha = 0.25$, поглощают свет).
- Высокая температура выходит за оптимум размножения ---
  чёрные маргаритки начинают вымирать.
- Условия становятся благоприятнее для белых маргариток
  (высокое альбедо $\alpha = 0.75$, охлаждают среду).
- И наоборот --- так возникают колебания.

## Сбор данных

Используем функцию `run!` из Agents.jl с параметром `adata` ---
на каждом шаге подсчитываем число чёрных и белых маргариток.

## Подключение пакетов

````@example daisyworld-count_literate
using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots
````

## Загрузка модели

````@example daisyworld-count_literate
include(srcdir("daisyworld.jl"))

using CairoMakie
````

## Определение функций подсчёта

Функции-предикаты для фильтрации агентов по виду:

````@example daisyworld-count_literate
black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]
````

## Создание и запуск модели

Создаём модель с солнечной светимостью $L = 1.0$ (по умолчанию)
и прогоняем на 1000 шагов.

````@example daisyworld-count_literate
model = daisyworld(; solar_luminosity = 1.0)

agent_df, model_df = run!(model, 1000; adata)
````

## Построение графика

По оси X --- модельное время (tick), по оси Y --- число маргариток.
Чёрные маргаритки --- чёрная линия, белые --- оранжевая.

````@example daisyworld-count_literate
figure = Figure(size = (600, 400));

ax = figure[1, 1] = Axis(figure, xlabel = "tick", ylabel = "daisy count")
blackl = lines!(ax, agent_df[!, :time], agent_df[!, :count_black], color = :black)
whitel = lines!(ax, agent_df[!, :time], agent_df[!, :count_white], color = :orange)
Legend(figure[1, 2], [blackl, whitel], ["black", "white"], labelsize = 12)
````

## Сохранение

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

