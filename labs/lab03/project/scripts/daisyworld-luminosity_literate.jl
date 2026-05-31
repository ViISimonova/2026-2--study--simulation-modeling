# # Динамика модели Daisyworld
#
# ## Введение
#
# Построим комплексный график изменения числа маргариток, температуры
# и солнечной светимости в зависимости от модельного времени.
#
# Используем сценарий `:ramp` --- солнечная светимость
# сначала увеличивается, потом снижается:
#
# - Шаги 0--200: $L = \text{const} = 1.0$
# - Шаги 200--400: $L$ увеличивается на $\Delta L = 0.005$ каждый шаг
# - Шаги 400--500: $L = \text{const}$ (на достигнутом уровне)
# - Шаги 500--750: $L$ уменьшается на $\Delta L / 2 = 0.0025$ каждый шаг
# - Шаги 750--1000: $L = \text{const}$
#
# ## Саморегуляция
#
# Ключевое наблюдение: маргаритки **стабилизируют температуру** планеты.
#
# - При росте светимости белых маргариток становится больше ---
#   они отражают свет (альбедо $\alpha = 0.75$) и компенсируют перегрев.
# - При снижении светимости чёрных маргариток становится больше ---
#   они поглощают свет (альбедо $\alpha = 0.25$) и компенсируют охлаждение.
#
# Однако при **достаточно сильном** внешнем воздействии маргаритки
# не справляются с регуляцией и вымирают.
#
# ## Сбор данных
#
# Собираем данные агентов (`adata`) и данные модели (`mdata`):
# - `adata`: число чёрных и белых маргариток на каждом шаге
# - `mdata`: средняя температура поверхности и солнечная светимость

# ## Подключение пакетов

using DrWatson
@quickactivate "project"
using Agents
using DataFrames
using Plots

# ## Загрузка модели

include(srcdir("daisyworld.jl"))

using CairoMakie

# ## Функции подсчёта агентов

black(a) = a.breed == :black
white(a) = a.breed == :white
adata = [(black, count), (white, count)]

# ## Создание модели со сценарием ramp
#
# Солнечная светимость начинается с $L = 1.0$ и меняется по сценарию.

model = daisyworld(solar_luminosity = 1.0, scenario = :ramp)

# ## Определение метрик модели
#
# Средняя температура поверхности вычисляется как среднее
# по всем клеткам сетки:

temperature(model) = StatsBase.mean(model.temperature)
mdata = [temperature, :solar_luminosity]

# ## Запуск симуляции на 1000 шагов

agent_df, model_df = run!(model, 1000; adata = adata, mdata = mdata)

# ## Построение комплексного графика
#
# Три панели:
# 1. Число маргариток (красная --- чёрные, синяя --- белые)
# 2. Средняя температура поверхности
# 3. Солнечная светимость

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
figure

# ## Сохранение

#jl save(plotsdir("daisy_luminosity.png"), figure)
