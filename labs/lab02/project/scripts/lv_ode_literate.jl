# # Модель Лотки-Вольтерры (хищник-жертва)
#
# Система уравнений:
#
# $$\frac{dx}{dt} = \alpha x - \beta x y$$
# $$\frac{dy}{dt} = \delta x y - \gamma y$$
#
# Где:
# - $x$ --- популяция жертв (например, зайцы)
# - $y$ --- популяция хищников (например, лисы)
# - $\alpha$ --- естественный прирост жертв (в отсутствие хищников)
# - $\beta$ --- коэффициент поедания жертв хищниками
# - $\delta$ --- коэффициент прироста хищников за счет поедания жертв
# - $\gamma$ --- естественная смертность хищников (в отсутствие жертв)

# ## Подключение пакетов

using DrWatson

@quickactivate "lab_02_models"
using DifferentialEquations
using DataFrames
using StatsPlots
using LaTeXStrings
using Plots
using Statistics
using FFTW

#jl script_name = splitext(basename(PROGRAM_FILE))[1]
#nb script_name = "lv_ode"
#jl mkpath(plotsdir(script_name))
#jl mkpath(datadir(script_name))

# ## Определение системы ОДУ

function lotka_volterra!(du, u, p, t)
    x, y = u              ## x - жертвы, y - хищники
    α, β, δ, γ = p        ## параметры модели
    @inbounds begin
        du[1] = α*x - β*x*y   ## уравнение для жертв
        du[2] = δ*x*y - γ*y   ## уравнение для хищников
    end
    nothing
end

# ## Параметры модели и начальные условия

p_lv = [0.1,    ## α: скорость размножения жертв
        0.02,   ## β: скорость поедания жертв хищниками
        0.01,   ## δ: коэффициент конверсии пищи (жертв) в хищников
        0.3]    ## γ: смертность хищников

u0_lv = [40.0, 9.0]       ## начальная популяция [жертвы, хищники]
tspan_lv = (0.0, 200.0)   ## длительность симуляции
dt_lv = 0.01              ## шаг интегрирования

# ## Создание и решение задачи

prob_lv = ODEProblem(lotka_volterra!, u0_lv, tspan_lv, p_lv)
sol_lv = solve(prob_lv,
    dt = dt_lv,
    Tsit5(),               ## Метод 5-го порядка
    reltol=1e-8,           ## Относительная точность
    abstol=1e-10,          ## Абсолютная точность
    saveat=0.1,            ## Сохраняем каждые 0.1 единицы времени
    dense=true             ## Включаем плотный вывод для интерполяции
)

# ## Подготовка данных

df_lv = DataFrame()
df_lv[!, :t] = sol_lv.t
df_lv[!, :prey] = [u[1] for u in sol_lv.u]
df_lv[!, :predator] = [u[2] for u in sol_lv.u]

## Рассчет производных для анализа
df_lv[!, :dprey_dt] = p_lv[1] .* df_lv.prey .- p_lv[2] .* df_lv.prey .* df_lv.predator
df_lv[!, :dpredator_dt] = p_lv[3] .* df_lv.prey .* df_lv.predator .- p_lv[4] .* df_lv.predator

# ## Вывод информации о модели

println("="^60)
println("Модель Лотки-Вольтерры (хищник-жертва)")
println("="^60)
println("\nПараметры модели:")
println("α (скорость размножения жертв) = ", p_lv[1])
println("β (скорость поедания жертв) = ", p_lv[2])
println("δ (коэффициент конверсии) = ", p_lv[3])
println("γ (смертность хищников) = ", p_lv[4])
println("\nНачальные условия:")
println("Жертвы (x0) = ", u0_lv[1])
println("Хищники (y0) = ", u0_lv[2])

# ## Стационарные точки

x_star = p_lv[4] / p_lv[3]   ## стационарная точка для жертв
y_star = p_lv[1] / p_lv[2]   ## стационарная точка для хищников
println("\nСтационарные точки (положения равновесия):")
println("x* = γ/δ = ", round(x_star, digits=3))
println("y* = α/β = ", round(y_star, digits=3))

# ## Построение графиков
#
# ### График 1: Динамика популяций во времени

plt1 = plot(df_lv.t, [df_lv.prey df_lv.predator],
    label=[L"Жертвы (x)" L"Хищники (y)"],
    xlabel="Время",
    ylabel="Популяция",
    title="Модель Лотки-Вольтерры: Динамика популяций",
    linewidth=2,
    legend=:topright,
    grid=true,
    size=(900, 500),
    color=[:green :red])
hline!(plt1, [x_star], color=:green, linestyle=:dash, alpha=0.5, label="x* (равновесие жертв)")
hline!(plt1, [y_star], color=:red, linestyle=:dash, alpha=0.5, label="y* (равновесие хищников)")

# ### График 2: Фазовый портрет (хищники vs жертвы)

plt2 = plot(df_lv.prey, df_lv.predator,
    label="Фазовая траектория",
    xlabel="Популяция жертв (x)",
    ylabel="Популяция хищников (y)",
    title="Фазовый портрет системы",
    color=:blue,
    linewidth=1.5,
    grid=true,
    size=(800, 600),
    legend=:topright)
## Добавление стрелок направления на фазовом портрете
step = 50
for i in 1:step:length(df_lv.prey)-step
    plot!(plt2, [df_lv.prey[i], df_lv.prey[i+step]],
        [df_lv.predator[i], df_lv.predator[i+step]],
        arrow=:closed, color=:blue, alpha=0.3, label=false)
end
## Добавление стационарной точки
scatter!(plt2, [x_star], [y_star],
    color=:black, markersize=8, label="Стационарная точка (x*, y*)")
## Изоклины (нулевого роста)
x_range = LinRange(0, maximum(df_lv.prey)*1.1, 100)
y_nullcline = p_lv[1] ./ (p_lv[2] .* x_range)
plot!(plt2, x_range, y_nullcline,
    color=:red, linestyle=:dash, linewidth=1.5, label="Изоклина хищников (dy/dt=0)")
y_range = LinRange(0, maximum(df_lv.predator)*1.1, 100)
x_nullcline = p_lv[4] ./ (p_lv[3] .* ones(length(y_range)))
plot!(plt2, x_nullcline, y_range,
    color=:green, linestyle=:dash, linewidth=1.5, label="Изоклина жертв (dx/dt=0)")

# ### График 3: Производные (скорости изменения)

plt3 = plot(df_lv.t, [df_lv.dprey_dt df_lv.dpredator_dt],
    label=[L"dx/dt" L"dy/dt"],
    xlabel="Время",
    ylabel="Скорость изменения",
    title="Производные популяций",
    linewidth=1.5,
    legend=:topright,
    grid=true,
    size=(900, 400),
    color=[:green :red])
hline!(plt3, [0], color=:black, linestyle=:solid, alpha=0.3, label=false)

# ### График 4: Относительные изменения (в %)

df_lv[!, :prey_pct_change] = df_lv.dprey_dt ./ df_lv.prey .* 100
df_lv[!, :predator_pct_change] = df_lv.dpredator_dt ./ df_lv.predator .* 100
plt4 = plot(df_lv.t, [df_lv.prey_pct_change df_lv.predator_pct_change],
    label=[L"dx/dt / x (\%)" L"dy/dt / y (\%)"],
    xlabel="Время",
    ylabel="Относительное изменение, %",
    title="Относительные темпы роста",
    linewidth=1.5,
    legend=:topright,
    grid=true,
    size=(900, 400),
    color=[:green :red])

# ### График 5: Спектральный анализ (быстрое преобразование Фурье)

function compute_fft(signal, dt)
    n = length(signal)
    spectrum = abs.(rfft(signal))
    freq = rfftfreq(n, 1/dt)
    return freq, spectrum
end

freq_prey, spectrum_prey = compute_fft(df_lv.prey .- mean(df_lv.prey), dt_lv)
freq_predator, spectrum_predator = compute_fft(df_lv.predator .- mean(df_lv.predator), dt_lv)
plt5 = plot(freq_prey, [spectrum_prey spectrum_predator],
    label=[L"Жертвы (x)" L"Хищники (y)"],
    xlabel="Частота",
    ylabel="Амплитуда",
    title="Спектральный анализ (Фурье)",
    linewidth=1.5,
    xscale=:log10,
    yscale=:log10,
    legend=:topright,
    grid=true,
    size=(800, 400),
    color=[:green :red])

## Нахождение доминирующих частот
if length(spectrum_prey) > 0
    idx_prey = argmax(spectrum_prey[2:end]) + 1
    dominant_freq_prey = freq_prey[idx_prey]
    period_prey = 1/dominant_freq_prey
    println("\nДоминирующая частота колебаний жертв: ", round(dominant_freq_prey, digits=4), " Гц")
    println("Период колебаний жертв: ", round(period_prey, digits=2), " единиц времени")
end

# ### График 6: Компактная панель всех графиков

plt6 = plot(layout=(3, 2), size=(1200, 900))
plot!(plt6[1], df_lv.t, df_lv.prey, label=L"x(t)", color=:green, linewidth=2,
    title="Популяция жертв", grid=true)
plot!(plt6[2], df_lv.t, df_lv.predator, label=L"y(t)", color=:red, linewidth=2,
    title="Популяция хищников", grid=true)
plot!(plt6[3], df_lv.prey, df_lv.predator, label=false, color=:blue, linewidth=1.5,
    title="Фазовый портрет", xlabel=L"x", ylabel=L"y", grid=true)
scatter!(plt6[3], [x_star], [y_star], color=:black, markersize=5, label="(x*, y*)")
plot!(plt6[4], df_lv.t, [df_lv.dprey_dt df_lv.dpredator_dt],
    label=[L"dx/dt" L"dy/dt"], color=[:green :red], linewidth=1.5,
    title="Скорости изменения", grid=true, legend=:topright)
plot!(plt6[5], freq_prey, spectrum_prey, label=L"x", color=:green, linewidth=1.5,
    title="Спектр жертв", xscale=:log10, yscale=:log10, grid=true)
plot!(plt6[6], df_lv.t, [df_lv.prey_pct_change df_lv.predator_pct_change],
    label=[L"dx/x" L"dy/y"], color=[:green :red], linewidth=1.5,
    title="Относительные изменения", grid=true, legend=:topright)

# ## Анализ результатов

println("\n" * "="^60)
println("Анализ результатов")
println("="^60)

println("\nОсновные статистики:")
println("Жертвы: min = ", round(minimum(df_lv.prey), digits=2),
    ", max = ", round(maximum(df_lv.prey), digits=2),
    ", mean = ", round(mean(df_lv.prey), digits=2))
println("Хищники: min = ", round(minimum(df_lv.predator), digits=2),
    ", max = ", round(maximum(df_lv.predator), digits=2),
    ", mean = ", round(mean(df_lv.predator), digits=2))

## Находим время первого пика жертв (простой алгоритм)
function find_first_peak(signal, time)
    for i in 2:length(signal)-1
        if signal[i] > signal[i-1] && signal[i] > signal[i+1]
            return time[i], signal[i]
        end
    end
    return NaN, NaN
end

peak_time_prey, peak_value_prey = find_first_peak(df_lv.prey, df_lv.t)
peak_time_predator, peak_value_predator = find_first_peak(df_lv.predator, df_lv.t)
if !isnan(peak_time_prey) && !isnan(peak_time_predator)
    phase_shift = peak_time_predator - peak_time_prey
    println("\nАнализ колебаний:")
    println("Первый пик жертв: время = ", round(peak_time_prey, digits=2),
        ", значение = ", round(peak_value_prey, digits=2))
    println("Первый пик хищников: время = ", round(peak_time_predator, digits=2),
        ", значение = ", round(peak_value_predator, digits=2))
    println("Сдвиг фаз (хищники отстают): ", round(phase_shift, digits=2))
end

# ## Сохранение графиков

#jl savefig(plt1, plotsdir(script_name, "lv_dynamics.png"))
#jl savefig(plt2, plotsdir(script_name, "lv_phase_portrait.png"))
#jl savefig(plt3, plotsdir(script_name, "lv_derivatives.png"))
#jl savefig(plt4, plotsdir(script_name, "lv_relative_changes.png"))
#jl savefig(plt5, plotsdir(script_name, "lv_spectrum.png"))
#jl savefig(plt6, plotsdir(script_name, "lv_panel.png"))

# ## Анализ чувствительности
#
# Варьируем по одному параметру за раз, сравнивая с базовым сценарием.

println("\n\n" * "="^60)
println("Анализ чувствительности")
println("="^60)

param_sets_lv = [
    (label="Базовый",                    alpha=0.10, beta=0.02, delta=0.01, gamma=0.30),
    (label="α=0.20 (быстрый прирост)",   alpha=0.20, beta=0.02, delta=0.01, gamma=0.30),
    (label="β=0.04 (усил. хищничество)", alpha=0.10, beta=0.04, delta=0.01, gamma=0.30),
    (label="γ=0.15 (живучие хищники)",   alpha=0.10, beta=0.02, delta=0.01, gamma=0.15),
]

plt_sens_prey = plot(title="Динамика жертв", xlabel="Время", ylabel="Жертвы (x)",
    legend=:topright, grid=true, size=(900, 400))
plt_sens_pred = plot(title="Динамика хищников", xlabel="Время", ylabel="Хищники (y)",
    legend=:topright, grid=true, size=(900, 400))
plt_sens_phase = plot(title="Фазовые портреты", xlabel="Жертвы (x)", ylabel="Хищники (y)",
    legend=:topright, grid=true, size=(800, 600))

for ps in param_sets_lv
    p_s = [ps.alpha, ps.beta, ps.delta, ps.gamma]
    prob_s = ODEProblem(lotka_volterra!, u0_lv, tspan_lv, p_s)
    sol_s = solve(prob_s, Tsit5(), dt=dt_lv, reltol=1e-8, abstol=1e-10, saveat=0.1)

    prey_s = [u[1] for u in sol_s.u]
    pred_s = [u[2] for u in sol_s.u]

    x_eq = ps.gamma / ps.delta
    y_eq = ps.alpha / ps.beta
    T_theory = 2π / sqrt(ps.alpha * ps.gamma)

    println("\n$(ps.label):")
    println("  x* = $(round(x_eq, digits=1)), y* = $(round(y_eq, digits=1))")
    println("  T (теор.) = $(round(T_theory, digits=1))")
    println("  x: min=$(round(minimum(prey_s), digits=1)), max=$(round(maximum(prey_s), digits=1))")
    println("  y: min=$(round(minimum(pred_s), digits=1)), max=$(round(maximum(pred_s), digits=1))")

    plot!(plt_sens_prey, sol_s.t, prey_s, label=ps.label, linewidth=1.5)
    plot!(plt_sens_pred, sol_s.t, pred_s, label=ps.label, linewidth=1.5)
    plot!(plt_sens_phase, prey_s, pred_s, label=ps.label, linewidth=1.5)
    scatter!(plt_sens_phase, [x_eq], [y_eq], label=false, markersize=5)
end

# ### Сводная панель анализа чувствительности

plt_sens_lv_panel = plot(plt_sens_prey, plt_sens_pred, plt_sens_phase,
    layout=@layout([a; b; c]), size=(1000, 1200))

#jl savefig(plt_sens_prey, plotsdir(script_name, "lv_sensitivity_prey.png"))
#jl savefig(plt_sens_pred, plotsdir(script_name, "lv_sensitivity_predator.png"))
#jl savefig(plt_sens_phase, plotsdir(script_name, "lv_sensitivity_phase.png"))
#jl savefig(plt_sens_lv_panel, plotsdir(script_name, "lv_sensitivity_panel.png"))

println("\nАнализ чувствительности LV завершён!")
println("\nМоделирование завершено успешно!")
