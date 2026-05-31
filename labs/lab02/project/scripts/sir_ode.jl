# # Модель SIR (эпидемиология)
#
# Система уравнений:
#
# $$\frac{dS}{dt} = -\beta c \frac{I}{N} S$$
# $$\frac{dI}{dt} = \beta c \frac{I}{N} S - \gamma I$$
# $$\frac{dR}{dt} = \gamma I$$
#
# Где:
# - $S$ --- восприимчивые (susceptible)
# - $I$ --- инфицированные (infected)
# - $R$ --- выздоровевшие (recovered)
# - $\beta$ --- вероятность заражения при контакте
# - $c$ --- среднее число контактов в единицу времени
# - $\gamma$ --- скорость выздоровления
# - $N = S + I + R$ --- общая численность популяции
# - $R_0 = \beta c / \gamma$ --- базовое репродуктивное число

# ## Подключение пакетов

using DrWatson

@quickactivate "lab_02_models"
using DifferentialEquations
using SimpleDiffEq
using Tables
using DataFrames
using StatsPlots
using LaTeXStrings
using Plots
using BenchmarkTools

#jl script_name = splitext(basename(PROGRAM_FILE))[1]
#nb script_name = "sir_ode"
#jl mkpath(plotsdir(script_name))
#jl mkpath(datadir(script_name))

# ## Определение системы ОДУ

function sir_ode!(du, u, p, t)
    (S, I, R) = u          ## S - восприимчивые, I - инфицированные, R - выздоровевшие
    (β, c, γ) = p          ## параметры модели
    N = S + I + R           ## общая численность
    @inbounds begin
        du[1] = -β * c * I / N * S       ## dS/dt
        du[2] = β * c * I / N * S - γ * I ## dI/dt
        du[3] = γ * I                      ## dR/dt
    end
    nothing
end

# ## Параметры модели и начальные условия

δt = 0.1                  ## шаг интегрирования
tmax = 40.0               ## максимальное время симуляции
tspan = (0.0, tmax)
u0 = [990.0, 10.0, 0.0]   ## [S0, I0, R0]
p = [0.05, 10.0, 0.25]    ## [β, c, γ]

## Расчет базового репродуктивного числа
R0 = (p[2] * p[1]) / p[3] ## R0 = (c * β) / γ

# ## Создание и решение задачи

prob_ode = ODEProblem(sir_ode!, u0, tspan, p)
sol_ode = solve(prob_ode, dt = δt)

# ## Подготовка данных

df_ode = DataFrame(Tables.table(sol_ode'))
rename!(df_ode, ["S", "I", "R"])
df_ode[!, :t] = sol_ode.t
df_ode[!, :N] = df_ode.S + df_ode.I + df_ode.R

# ## Вывод параметров модели

println("Параметры модели SIR:")
println("β (вероятность заражения) = ", p[1])
println("c (среднее число контактов) = ", p[2])
println("γ (скорость выздоровления) = ", p[3])
println("R0 = c * β / γ = ", round(R0, digits=3))
println("Средняя продолжительность болезни = ", round(1/p[3], digits=2), " дней")
println("Начальные условия: S0 = ", u0[1], ", I0 = ", u0[2], ", R0 = ", u0[3])

# ## Построение графиков
#
# ### График 1: Динамика всех трёх групп

plt1 = @df df_ode plot(:t,
    [:S :I :R],
    label=[L"S(t)" L"I(t)" L"R(t)"],
    xlabel="Время, дни",
    ylabel="Количество людей",
    title="Модель SIR: Динамика эпидемии",
    linewidth=2,
    legend=:right,
    grid=true,
    size=(800, 500))
## Добавление аннотаций с параметрами
annotate!(plt1, maximum(df_ode.t) * 0.7, maximum(df_ode.N) * 0.8,
    text("Параметры:\nβ = $(p[1])\nc = $(p[2])\nγ = $(p[3])\nR0 = $(round(R0, digits=2))",
    8, :left))

# ### График 2: Динамика числа инфицированных

plt2 = @df df_ode plot(:t, :I,
    label=L"I(t)",
    xlabel="Время, дни",
    ylabel="Количество инфицированных",
    title="Динамика числа зараженных",
    color=:red,
    linewidth=2,
    fill=(0, 0.3, :red),
    grid=true,
    size=(800, 400))
## Отметка пика эпидемии
peak_idx = argmax(df_ode.I)
peak_time = df_ode.t[peak_idx]
peak_value = df_ode.I[peak_idx]
vline!(plt2, [peak_time], color=:black, linestyle=:dash, label=false, linewidth=1)
annotate!(plt2, peak_time, peak_value * 1.05,
    text("Пик: $(round(peak_value, digits=1)) на $(round(peak_time, digits=1)) день",
    8, :top))

# ### График 3: Логарифмический масштаб (экспоненциальный рост)

plt3 = @df df_ode plot(:t, :I,
    label=L"I(t)",
    xlabel="Время, дни",
    ylabel="Количество инфицированных (лог. масштаб)",
    title="Экспоненциальный рост (лог. шкала)",
    yscale=:log10,
    color=:red,
    linewidth=2,
    grid=true,
    size=(800, 400))

# ### График 4: Доли населения (в процентах)

plt4 = @df df_ode plot(:t,
    [:S :I :R] ./ df_ode.N .* 100,
    label=[L"S(t)/N" L"I(t)/N" L"R(t)/N"],
    xlabel="Время, дни",
    ylabel="Доля популяции, %",
    title="Динамика эпидемии (в процентах)",
    linewidth=2,
    legend=:right,
    grid=true,
    size=(800, 500))
## Горизонтальная линия для порога коллективного иммунитета
if R0 > 1
    herd_immunity_threshold = (1 - 1/R0) * 100
    hline!(plt4, [herd_immunity_threshold], color=:purple, linestyle=:dash,
        label="Порог коллективного иммунитета ($(round(herd_immunity_threshold, digits=1))%)",
        linewidth=1.5)
end

# ### График 5: Фазовый портрет (I vs S)

plt5 = plot(df_ode.S, df_ode.I,
    label="Фазовая траектория",
    xlabel=L"S(t)",
    ylabel=L"I(t)",
    title="Фазовый портрет SIR модели",
    color=:blue,
    linewidth=2,
    grid=true,
    size=(800, 500),
    legend=:topright)
## Добавление стрелок направления
for i in 1:50:length(df_ode.S)-1
    plot!(plt5, [df_ode.S[i], df_ode.S[i+1]], [df_ode.I[i], df_ode.I[i+1]],
        arrow=:closed, color=:blue, alpha=0.5, label=false)
end

# ### График 6: Эффективное репродуктивное число $R_e$

df_ode[!, :Re] = R0 .* df_ode.S ./ df_ode.N

plt6 = @df df_ode plot(:t, :Re,
    label=L"R_e(t)",
    xlabel="Время, дни",
    ylabel=L"R_e",
    title="Динамика эффективного репродуктивного числа",
    color=:green,
    linewidth=2,
    grid=true,
    size=(800, 400))
## Горизонтальная линия на уровне 1
hline!(plt6, [1.0], color=:red, linestyle=:dash, label="Порог эпидемии (Rₑ=1)", linewidth=1.5)
## Отметка момента, когда Rₑ становится < 1
cross_idx = findfirst(x -> x < 1, df_ode.Re)
if !isnothing(cross_idx) && cross_idx > 1
    cross_time = df_ode.t[cross_idx]
    vline!(plt6, [cross_time], color=:black, linestyle=:dash, label=false, linewidth=1)
    annotate!(plt6, cross_time, 1.2,
        text("Rₑ<1 с $(round(cross_time, digits=1)) дня", 8, :left))
end

# ### График 7: Компактная панель всех кривых

plt7 = plot(layout=(2, 3), size=(1200, 800))
## Верхний ряд
plot!(plt7[1], df_ode.t, df_ode.S, label=L"S(t)", color=1, linewidth=2, title="Восприимчивые")
plot!(plt7[2], df_ode.t, df_ode.I, label=L"I(t)", color=2, linewidth=2, title="Зараженные")
plot!(plt7[3], df_ode.t, df_ode.R, label=L"R(t)", color=3, linewidth=2, title="Выздоровевшие")
## Нижний ряд
plot!(plt7[4], df_ode.t, df_ode.I, label=L"I(t)", color=2, linewidth=2,
    yscale=:log10, title="Лог. масштаб")
plot!(plt7[5], df_ode.S, df_ode.I, label=false, color=4, linewidth=2,
    title="Фазовый портрет", xlabel=L"S", ylabel=L"I")
plot!(plt7[6], df_ode.t, df_ode.Re, label=L"R_e", color=:green, linewidth=2,
    title=L"R_e(t)", hline=[1.0], linestyle=:dash, linecolor=:red)

# ## Сохранение графиков

#jl savefig(plt1, plotsdir(script_name, "sir_main.png"))
#jl savefig(plt2, plotsdir(script_name, "sir_infected.png"))
#jl savefig(plt3, plotsdir(script_name, "sir_log_scale.png"))
#jl savefig(plt4, plotsdir(script_name, "sir_percentages.png"))
#jl savefig(plt5, plotsdir(script_name, "sir_phase_portrait.png"))
#jl savefig(plt6, plotsdir(script_name, "sir_effective_R.png"))
#jl savefig(plt7, plotsdir(script_name, "sir_panel.png"))

# ## Бенчмарк

println("\nБенчмарк решения:")
@benchmark solve(prob_ode, dt = δt)

# ## Анализ результатов

println("\n=== АНАЛИЗ РЕЗУЛЬТАТОВ ===")
println("Общая численность популяции (контроль): N = ", round(df_ode.N[1], digits=1))
println("Пиковое число зараженных: I_max = ", round(peak_value, digits=1))
println("Время достижения пика: t_peak = ", round(peak_time, digits=1), " дней")
println("Итоговое число переболевших: R(∞) = ", round(df_ode.R[end], digits=1))
println("Доля переболевших: ", round(df_ode.R[end]/df_ode.N[1]*100, digits=1), "%")
if R0 > 1
    println("\nТеоретический анализ:")
    println(" - Порог коллективного иммунитета: ", round((1-1/R0)*100, digits=1), "%")
    println(" - Теоретический пик при S/N = 1/R0 = ", round(1/R0, digits=3))
end

# ## Анализ чувствительности
#
# Варьируем $\beta$ при фиксированных $c = 10$ и $\gamma = 0.25$,
# получая $R_0$ от 0.5 до 4.0.

println("\n" * "="^60)
println("Анализ чувствительности SIR")
println("="^60)

param_sets_sir = [
    (label="R₀=0.5", beta=0.0125, c=10.0, gamma=0.25),
    (label="R₀=1.0", beta=0.0250, c=10.0, gamma=0.25),
    (label="R₀=2.0", beta=0.0500, c=10.0, gamma=0.25),
    (label="R₀=3.0", beta=0.0750, c=10.0, gamma=0.25),
    (label="R₀=4.0", beta=0.1000, c=10.0, gamma=0.25),
]

# ### Графики сравнения I(t) и $R_e(t)$

plt_sens_I = plot(title="Анализ чувствительности: I(t)", xlabel="Время, дни",
    ylabel="Инфицированные", legend=:topright, grid=true, size=(900, 500))
plt_sens_Re = plot(title="Анализ чувствительности: Rₑ(t)", xlabel="Время, дни",
    ylabel=L"R_e", legend=:topright, grid=true, size=(900, 500))
hline!(plt_sens_Re, [1.0], color=:black, linestyle=:dash, label="Rₑ=1", linewidth=1)

sens_results = DataFrame(R0=Float64[], I_max=Float64[], t_peak=Float64[], attack_rate=Float64[])

for ps in param_sets_sir
    p_s = [ps.beta, ps.c, ps.gamma]
    R0_s = ps.c * ps.beta / ps.gamma
    prob_s = ODEProblem(sir_ode!, u0, tspan, p_s)
    sol_s = solve(prob_s, dt=δt)

    df_s = DataFrame(Tables.table(sol_s'))
    rename!(df_s, ["S", "I", "R"])
    df_s[!, :t] = sol_s.t
    df_s[!, :N] = df_s.S .+ df_s.I .+ df_s.R

    ## Ключевые показатели
    i_max = maximum(df_s.I)
    t_max = df_s.t[argmax(df_s.I)]
    attack = df_s.R[end] / df_s.N[1] * 100
    push!(sens_results, (R0_s, i_max, t_max, attack))

    plot!(plt_sens_I, df_s.t, df_s.I, label=ps.label, linewidth=2)

    Re_s = R0_s .* df_s.S ./ df_s.N
    plot!(plt_sens_Re, df_s.t, Re_s, label=ps.label, linewidth=2)

    println("$(ps.label): I_max=$(round(i_max, digits=1)), t_peak=$(round(t_max, digits=1)), охват=$(round(attack, digits=1))%")
end

# ### Зависимость пика и охвата от $R_0$

plt_sens_summary = plot(layout=(1, 2), size=(1000, 400))
plot!(plt_sens_summary[1], sens_results.R0, sens_results.I_max,
    marker=:circle, linewidth=2, label=false,
    xlabel=L"R_0", ylabel=L"I_{max}", title="Пик заражённых vs R₀", grid=true)
plot!(plt_sens_summary[2], sens_results.R0, sens_results.attack_rate,
    marker=:circle, linewidth=2, label=false, color=:red,
    xlabel=L"R_0", ylabel="Охват, %", title="Доля переболевших vs R₀", grid=true)

# ### Сводная панель анализа чувствительности

plt_sens_panel = plot(plt_sens_I, plt_sens_Re, plt_sens_summary,
    layout=@layout([a b; c{0.4h}]), size=(1200, 900))

#jl savefig(plt_sens_I, plotsdir(script_name, "sir_sensitivity_I.png"))
#jl savefig(plt_sens_Re, plotsdir(script_name, "sir_sensitivity_Re.png"))
#jl savefig(plt_sens_summary, plotsdir(script_name, "sir_sensitivity_summary.png"))
#jl savefig(plt_sens_panel, plotsdir(script_name, "sir_sensitivity_panel.png"))

println("\nАнализ чувствительности SIR завершён!")
