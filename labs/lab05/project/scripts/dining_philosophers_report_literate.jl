# # ЛР 5. Итоговый отчёт по экспериментам
# В этом скрипте строится итоговый сравнительный график
# для классической сети и сети с арбитром.
#
# ## Подключение зависимостей

using DrWatson
@quickactivate "lab05_Petry"

using DataFrames, CSV, Plots

function main()
    # ## Загрузка результатов моделирования
    df_classic = CSV.read(datadir("dining_classic.csv"), DataFrame)
    df_arbiter = CSV.read(datadir("dining_arbiter.csv"), DataFrame)
    N = 5

    # ## Выбор столбцов для состояния Eat
    eat_cols = [Symbol("Eat_$i") for i = 1:N]

    # ## Построение итогового графика
    p1 = plot(
        df_classic.time,
        Matrix(df_classic[:, eat_cols]),
        label = ["Ф $i" for i = 1:N],
        xlabel = "Время",
        ylabel = "Ест (1/0)",
        title = "Классическая сеть",
    )
    p2 = plot(
        df_arbiter.time,
        Matrix(df_arbiter[:, eat_cols]),
        label = ["Ф $i" for i = 1:N],
        xlabel = "Время",
        ylabel = "Ест (1/0)",
        title = "Сеть с арбитром",
    )
    p_final = plot(p1, p2, layout = (2, 1), size = (800, 600))
    savefig(p_final, plotsdir("final_report.png"))

    println("Отчёт сохранён в plots/final_report.png")
end

main()
