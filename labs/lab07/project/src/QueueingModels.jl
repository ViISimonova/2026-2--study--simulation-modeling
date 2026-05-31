module QueueingModels

using CSV
using DataFrames
using Distributions
using LinearAlgebra
using Plots
using StableRNGs
using Statistics

export mmc_analytic,
    simulate_mmc,
    run_mmc_experiment,
    run_mmc_parameter_scan,
    ross_analytic_crash_time,
    simulate_ross_once,
    run_ross_experiment,
    run_ross_parameter_scan

function ensure_output_dirs(data_dir::AbstractString = "data", plots_dir::AbstractString = "plots")
    mkpath(data_dir)
    mkpath(plots_dir)
    return data_dir, plots_dir
end

function mmc_analytic(lambda::Real, mu::Real, c::Integer)
    rho = lambda / (c * mu)
    if rho >= 1
        return (
            rho = Float64(rho),
            p0 = NaN,
            pwait = NaN,
            lq = Inf,
            wq = Inf,
            w = Inf,
            l = Inf,
        )
    end

    a = c * rho
    finite_sum = sum(a^n / factorial(n) for n in 0:(c - 1))
    tail = a^c / (factorial(c) * (1 - rho))
    p0 = 1 / (finite_sum + tail)
    pwait = tail * p0
    lq = rho / (1 - rho) * pwait
    wq = lq / lambda
    w = wq + 1 / mu
    l = lambda * w

    return (
        rho = Float64(rho),
        p0 = Float64(p0),
        pwait = Float64(pwait),
        lq = Float64(lq),
        wq = Float64(wq),
        w = Float64(w),
        l = Float64(l),
    )
end

function build_mmc_events(customers::DataFrame)
    raw = NamedTuple[]
    for row in eachrow(customers)
        push!(raw, (time = row.arrival_time, priority = 1, event = "arrival", id = row.id))
        push!(raw, (time = row.service_start, priority = 2, event = "service_start", id = row.id))
        push!(raw, (time = row.departure_time, priority = 3, event = "departure", id = row.id))
    end
    sort!(raw; by = x -> (x.time, x.priority, x.id))

    queue_length = 0
    busy_servers = 0
    rows = NamedTuple[]

    for event in raw
        if event.event == "arrival"
            queue_length += 1
        elseif event.event == "service_start"
            queue_length = max(queue_length - 1, 0)
            busy_servers += 1
        elseif event.event == "departure"
            busy_servers = max(busy_servers - 1, 0)
        end

        push!(
            rows,
            (
                time = Float64(event.time),
                event = event.event,
                customer_id = Int(event.id),
                queue_length = Int(queue_length),
                busy_servers = Int(busy_servers),
                system_size = Int(queue_length + busy_servers),
            ),
        )
    end

    return DataFrame(rows)
end

function time_weighted_mean(events::DataFrame, column::Symbol; from_time::Real = 0.0, to_time::Real)
    nrow(events) < 2 && return 0.0
    total = 0.0
    duration = max(Float64(to_time - from_time), 0.0)
    duration == 0 && return 0.0

    for i in 1:(nrow(events) - 1)
        t0 = max(Float64(events.time[i]), Float64(from_time))
        t1 = min(Float64(events.time[i + 1]), Float64(to_time))
        if t1 > t0
            total += Float64(events[i, column]) * (t1 - t0)
        end
    end

    return total / duration
end

function simulate_mmc(;
    lambda::Real = 0.9,
    mu::Real = 0.5,
    c::Integer = 2,
    num_customers::Integer = 5000,
    seed::Integer = 123,
    warmup_fraction::Real = 0.1,
)
    rng = StableRNG(seed)
    interarrival_dist = Exponential(1 / lambda)
    service_dist = Exponential(1 / mu)

    server_available = zeros(Float64, c)
    arrival_time = 0.0
    rows = NamedTuple[]

    for id in 1:num_customers
        arrival_time += rand(rng, interarrival_dist)
        server_id = findmin(server_available)[2]
        service_start = max(arrival_time, server_available[server_id])
        service_time = rand(rng, service_dist)
        departure_time = service_start + service_time
        server_available[server_id] = departure_time

        push!(
            rows,
            (
                id = id,
                arrival_time = arrival_time,
                service_start = service_start,
                departure_time = departure_time,
                wait_time = service_start - arrival_time,
                service_time = service_time,
                system_time = departure_time - arrival_time,
                server_id = server_id,
            ),
        )
    end

    customers = DataFrame(rows)
    events = build_mmc_events(customers)
    analytic = mmc_analytic(lambda, mu, c)

    warmup_count = clamp(floor(Int, warmup_fraction * num_customers), 0, num_customers - 1)
    tail = customers[(warmup_count + 1):end, :]
    warmup_time = warmup_count == 0 ? 0.0 : customers.arrival_time[warmup_count]
    end_time = maximum(customers.departure_time)

    sim_wq = mean(tail.wait_time)
    sim_w = mean(tail.system_time)
    sim_lq = time_weighted_mean(events, :queue_length; from_time = warmup_time, to_time = end_time)
    sim_l = time_weighted_mean(events, :system_size; from_time = warmup_time, to_time = end_time)
    sim_busy = time_weighted_mean(events, :busy_servers; from_time = warmup_time, to_time = end_time)

    summary = DataFrame(
        lambda = [Float64(lambda)],
        mu = [Float64(mu)],
        c = [Int(c)],
        num_customers = [Int(num_customers)],
        seed = [Int(seed)],
        rho = [analytic.rho],
        analytic_wq = [analytic.wq],
        sim_wq = [sim_wq],
        analytic_w = [analytic.w],
        sim_w = [sim_w],
        analytic_lq = [analytic.lq],
        sim_lq = [sim_lq],
        analytic_l = [analytic.l],
        sim_l = [sim_l],
        analytic_pwait = [analytic.pwait],
        sim_pwait = [mean(tail.wait_time .> 1.0e-9)],
        sim_utilization = [sim_busy / c],
    )

    return (customers = customers, events = events, summary = summary)
end

function save_mmc_plots(customers::DataFrame, events::DataFrame, summary::DataFrame, plots_dir::AbstractString)
    p_queue = plot(
        events.time,
        events.queue_length;
        seriestype = :steppost,
        label = "queue",
        xlabel = "time",
        ylabel = "queue length",
        title = "M/M/c queue length",
    )
    savefig(p_queue, joinpath(plots_dir, "mmc_queue_length.png"))

    p_busy = plot(
        events.time,
        events.busy_servers;
        seriestype = :steppost,
        label = "busy servers",
        xlabel = "time",
        ylabel = "busy servers",
        title = "M/M/c busy servers",
    )
    savefig(p_busy, joinpath(plots_dir, "mmc_busy_servers.png"))

    p_wait = histogram(
        customers.wait_time;
        bins = 40,
        label = "wait time",
        xlabel = "wait time",
        ylabel = "customers",
        title = "M/M/c wait time distribution",
    )
    savefig(p_wait, joinpath(plots_dir, "mmc_wait_histogram.png"))

    values = [
        summary.analytic_wq[1] summary.sim_wq[1]
        summary.analytic_w[1] summary.sim_w[1]
        summary.analytic_lq[1] summary.sim_lq[1]
        summary.analytic_l[1] summary.sim_l[1]
    ]
    p_cmp = bar(
        ["Wq", "W", "Lq", "L"],
        values;
        label = ["analytic" "simulation"],
        xlabel = "metric",
        ylabel = "value",
        title = "M/M/c analytic vs simulation",
    )
    savefig(p_cmp, joinpath(plots_dir, "mmc_analytic_vs_simulation.png"))

    return nothing
end

function run_mmc_experiment(;
    lambda::Real = 0.9,
    mu::Real = 0.5,
    c::Integer = 2,
    num_customers::Integer = 5000,
    seed::Integer = 123,
    data_dir::AbstractString = "data",
    plots_dir::AbstractString = "plots",
)
    ensure_output_dirs(data_dir, plots_dir)
    result = simulate_mmc(; lambda = lambda, mu = mu, c = c, num_customers = num_customers, seed = seed)

    CSV.write(joinpath(data_dir, "mmc_customers.csv"), result.customers)
    CSV.write(joinpath(data_dir, "mmc_events.csv"), result.events)
    CSV.write(joinpath(data_dir, "mmc_summary.csv"), result.summary)
    save_mmc_plots(result.customers, result.events, result.summary, plots_dir)

    println("M/M/c experiment completed.")
    println("Saved data/mmc_customers.csv")
    println("Saved data/mmc_events.csv")
    println("Saved data/mmc_summary.csv")
    println("Saved plots/mmc_queue_length.png")
    println("Saved plots/mmc_busy_servers.png")
    println("Saved plots/mmc_wait_histogram.png")
    println("Saved plots/mmc_analytic_vs_simulation.png")

    return result
end

function run_mmc_parameter_scan(;
    lambdas = [0.3, 0.6, 0.9],
    channels = 1:6,
    mu::Real = 0.5,
    num_customers::Integer = 3000,
    seed::Integer = 321,
    data_dir::AbstractString = "data",
    plots_dir::AbstractString = "plots",
)
    ensure_output_dirs(data_dir, plots_dir)
    rows = NamedTuple[]

    for lambda in lambdas, c in channels
        analytic = mmc_analytic(lambda, mu, c)
        if analytic.rho >= 1
            push!(
                rows,
                (
                    lambda = Float64(lambda),
                    mu = Float64(mu),
                    c = Int(c),
                    rho = analytic.rho,
                    analytic_wq = Inf,
                    sim_wq = NaN,
                    analytic_w = Inf,
                    sim_w = NaN,
                    sim_utilization = NaN,
                ),
            )
            continue
        end

        result = simulate_mmc(;
            lambda = lambda,
            mu = mu,
            c = c,
            num_customers = num_customers,
            seed = seed + 100 * c + round(Int, 1000 * lambda),
        )
        summary = result.summary[1, :]
        push!(
            rows,
            (
                lambda = Float64(lambda),
                mu = Float64(mu),
                c = Int(c),
                rho = summary.rho,
                analytic_wq = summary.analytic_wq,
                sim_wq = summary.sim_wq,
                analytic_w = summary.analytic_w,
                sim_w = summary.sim_w,
                sim_utilization = summary.sim_utilization,
            ),
        )
    end

    scan = DataFrame(rows)
    CSV.write(joinpath(data_dir, "mmc_parameter_scan.csv"), scan)

    stable = filter(:rho => <(1.0), scan)

    p_channels = plot(; xlabel = "servers", ylabel = "Wq", title = "M/M/c wait by channels")
    for lambda in lambdas
        part = filter(:lambda => ==(Float64(lambda)), stable)
        sort!(part, :c)
        plot!(p_channels, part.c, part.sim_wq; marker = :circle, label = "lambda=$(lambda)")
    end
    savefig(p_channels, joinpath(plots_dir, "mmc_wait_by_channels.png"))

    p_lambda = plot(; xlabel = "lambda", ylabel = "Wq", title = "M/M/c wait by arrival rate")
    for c in channels
        part = filter(:c => ==(Int(c)), stable)
        sort!(part, :lambda)
        nrow(part) > 0 && plot!(p_lambda, part.lambda, part.sim_wq; marker = :circle, label = "c=$(c)")
    end
    savefig(p_lambda, joinpath(plots_dir, "mmc_wait_by_lambda.png"))

    heat = fill(NaN, length(lambdas), length(channels))
    for row in eachrow(scan)
        i = findfirst(==(row.lambda), Float64.(lambdas))
        j = findfirst(==(row.c), Int.(channels))
        if i !== nothing && j !== nothing
            heat[i, j] = row.sim_utilization
        end
    end
    p_heat = heatmap(
        collect(channels),
        Float64.(lambdas),
        heat;
        xlabel = "servers",
        ylabel = "lambda",
        title = "M/M/c utilization",
        colorbar_title = "utilization",
    )
    savefig(p_heat, joinpath(plots_dir, "mmc_utilization_heatmap.png"))

    println("M/M/c parameter scan completed.")
    println("Saved data/mmc_parameter_scan.csv")
    println("Saved plots/mmc_wait_by_channels.png")
    println("Saved plots/mmc_wait_by_lambda.png")
    println("Saved plots/mmc_utilization_heatmap.png")

    return scan
end

function ross_analytic_crash_time(;
    N::Integer = 10,
    S::Integer = 3,
    repairers::Integer = 1,
    mean_time_to_failure::Real = 100.0,
    mean_repair_time::Real = 1.0,
)
    a = N / mean_time_to_failure
    mu = 1 / mean_repair_time
    m = S + 1
    A = zeros(Float64, m, m)
    b = ones(Float64, m)

    for s in 0:S
        idx = s + 1
        repair_rate = min(S - s, repairers) * mu
        if s == 0
            A[idx, idx] = a + repair_rate
            if S >= 1
                A[idx, idx + 1] = -repair_rate
            end
        elseif s == S
            A[idx, idx] = a
            A[idx, idx - 1] = -a
        else
            A[idx, idx] = a + repair_rate
            A[idx, idx - 1] = -a
            A[idx, idx + 1] = -repair_rate
        end
    end

    times = A \ b
    return times[S + 1]
end

function push_ross_event!(
    rows::Vector{NamedTuple},
    time::Real,
    event::AbstractString,
    N::Integer,
    spares::Integer,
    repair_queue::Integer,
    busy_repairers::Integer;
    crashed::Bool = false,
)
    working = crashed ? N - 1 : N
    push!(
        rows,
        (
            time = Float64(time),
            event = String(event),
            working = Int(working),
            spares = Int(spares),
            broken = Int(repair_queue + busy_repairers),
            repair_queue = Int(repair_queue),
            busy_repairers = Int(busy_repairers),
            good_machines = Int(working + spares),
        ),
    )
    return nothing
end

function schedule_repair!(completion_times::Vector{Float64}, now::Real, rng, repair_dist)
    push!(completion_times, Float64(now + rand(rng, repair_dist)))
    return nothing
end

function simulate_ross_once(;
    N::Integer = 10,
    S::Integer = 3,
    repairers::Integer = 1,
    mean_time_to_failure::Real = 100.0,
    mean_repair_time::Real = 1.0,
    seed::Integer = 150,
)
    rng = StableRNG(seed)
    failure_dist = Exponential(mean_time_to_failure / N)
    repair_dist = Exponential(mean_repair_time)

    now = 0.0
    spares = S
    repair_queue = 0
    busy_repairers = 0
    completion_times = Float64[]
    next_failure = rand(rng, failure_dist)
    rows = NamedTuple[]
    push_ross_event!(rows, now, "start", N, spares, repair_queue, busy_repairers)

    while true
        next_repair = isempty(completion_times) ? Inf : minimum(completion_times)

        if next_failure <= next_repair
            now = next_failure
            if spares == 0
                push_ross_event!(rows, now, "crash", N, spares, repair_queue, busy_repairers; crashed = true)
                break
            end

            spares -= 1
            push_ross_event!(rows, now, "failure", N, spares, repair_queue, busy_repairers)

            if busy_repairers < repairers
                busy_repairers += 1
                schedule_repair!(completion_times, now, rng, repair_dist)
                push_ross_event!(rows, now, "repair_start", N, spares, repair_queue, busy_repairers)
            else
                repair_queue += 1
                push_ross_event!(rows, now, "repair_queue", N, spares, repair_queue, busy_repairers)
            end

            next_failure = now + rand(rng, failure_dist)
        else
            now = next_repair
            deleteat!(completion_times, findfirst(==(next_repair), completion_times))
            busy_repairers -= 1
            spares += 1
            push_ross_event!(rows, now, "repair_finish", N, spares, repair_queue, busy_repairers)

            if repair_queue > 0 && busy_repairers < repairers
                repair_queue -= 1
                busy_repairers += 1
                schedule_repair!(completion_times, now, rng, repair_dist)
                push_ross_event!(rows, now, "repair_start", N, spares, repair_queue, busy_repairers)
            end
        end
    end

    events = DataFrame(rows)
    crash_time = now
    mean_queue = time_weighted_mean(events, :repair_queue; from_time = 0.0, to_time = crash_time)
    mean_busy = time_weighted_mean(events, :busy_repairers; from_time = 0.0, to_time = crash_time)
    utilization = mean_busy / repairers

    metrics = (
        crash_time = crash_time,
        mean_repair_queue = mean_queue,
        mean_busy_repairers = mean_busy,
        repairer_utilization = utilization,
    )

    return (crash_time = crash_time, events = events, metrics = metrics)
end

function save_ross_sample_plots(events::DataFrame, runs::DataFrame, summary::DataFrame, plots_dir::AbstractString)
    p_good = plot(
        events.time,
        events.good_machines;
        seriestype = :steppost,
        label = "good machines",
        xlabel = "time",
        ylabel = "machines",
        title = "Ross model good machines",
    )
    savefig(p_good, joinpath(plots_dir, "ross_good_machines.png"))

    p_spares = plot(
        events.time,
        events.spares;
        seriestype = :steppost,
        label = "spares",
        xlabel = "time",
        ylabel = "spares",
        title = "Ross model spares",
    )
    savefig(p_spares, joinpath(plots_dir, "ross_spares.png"))

    p_queue = plot(
        events.time,
        events.repair_queue;
        seriestype = :steppost,
        label = "repair queue",
        xlabel = "time",
        ylabel = "queue",
        title = "Ross model repair queue",
    )
    savefig(p_queue, joinpath(plots_dir, "ross_repair_queue.png"))

    p_hist = histogram(
        runs.crash_time;
        bins = 30,
        label = "crash time",
        xlabel = "time",
        ylabel = "runs",
        title = "Ross model crash time",
    )
    savefig(p_hist, joinpath(plots_dir, "ross_crash_time_histogram.png"))

    p_cmp = bar(
        ["simulation", "analytic"],
        [summary.mean_crash_time[1], summary.analytic_crash_time[1]];
        label = false,
        ylabel = "time",
        title = "Ross model simulation vs analytic",
    )
    savefig(p_cmp, joinpath(plots_dir, "ross_simulation_vs_analytic.png"))

    p_util = bar(
        ["repairers"],
        [summary.repairer_utilization[1]];
        label = false,
        ylabel = "utilization",
        ylim = (0, 1),
        title = "Ross model repairer utilization",
    )
    savefig(p_util, joinpath(plots_dir, "ross_repairer_utilization.png"))

    return nothing
end

function run_ross_experiment(;
    N::Integer = 10,
    S::Integer = 3,
    repairers::Integer = 1,
    mean_time_to_failure::Real = 100.0,
    mean_repair_time::Real = 1.0,
    runs::Integer = 300,
    seed::Integer = 150,
    data_dir::AbstractString = "data",
    plots_dir::AbstractString = "plots",
)
    ensure_output_dirs(data_dir, plots_dir)
    sample = simulate_ross_once(;
        N = N,
        S = S,
        repairers = repairers,
        mean_time_to_failure = mean_time_to_failure,
        mean_repair_time = mean_repair_time,
        seed = seed,
    )

    run_rows = NamedTuple[]
    for run_id in 1:runs
        result = simulate_ross_once(;
            N = N,
            S = S,
            repairers = repairers,
            mean_time_to_failure = mean_time_to_failure,
            mean_repair_time = mean_repair_time,
            seed = seed + run_id,
        )
        push!(
            run_rows,
            (
                run_id = run_id,
                crash_time = result.crash_time,
                mean_repair_queue = result.metrics.mean_repair_queue,
                repairer_utilization = result.metrics.repairer_utilization,
            ),
        )
    end

    runs_df = DataFrame(run_rows)
    analytic = ross_analytic_crash_time(;
        N = N,
        S = S,
        repairers = repairers,
        mean_time_to_failure = mean_time_to_failure,
        mean_repair_time = mean_repair_time,
    )
    summary = DataFrame(
        N = [N],
        S = [S],
        repairers = [repairers],
        runs = [runs],
        mean_crash_time = [mean(runs_df.crash_time)],
        std_crash_time = [std(runs_df.crash_time)],
        analytic_crash_time = [analytic],
        mean_repair_queue = [mean(runs_df.mean_repair_queue)],
        repairer_utilization = [mean(runs_df.repairer_utilization)],
    )

    CSV.write(joinpath(data_dir, "ross_events_sample.csv"), sample.events)
    CSV.write(joinpath(data_dir, "ross_runs.csv"), runs_df)
    CSV.write(joinpath(data_dir, "ross_summary.csv"), summary)
    save_ross_sample_plots(sample.events, runs_df, summary, plots_dir)

    println("Ross model experiment completed.")
    println("Saved data/ross_events_sample.csv")
    println("Saved data/ross_runs.csv")
    println("Saved data/ross_summary.csv")
    println("Saved plots/ross_good_machines.png")
    println("Saved plots/ross_spares.png")
    println("Saved plots/ross_repair_queue.png")
    println("Saved plots/ross_crash_time_histogram.png")
    println("Saved plots/ross_simulation_vs_analytic.png")
    println("Saved plots/ross_repairer_utilization.png")

    return (sample = sample, runs = runs_df, summary = summary)
end

function run_ross_parameter_scan(;
    N_values = [5, 10, 15, 20],
    S_values = [1, 3, 5],
    repairer_values = [1, 2, 3],
    mean_time_to_failure::Real = 100.0,
    mean_repair_time::Real = 1.0,
    runs::Integer = 100,
    seed::Integer = 500,
    data_dir::AbstractString = "data",
    plots_dir::AbstractString = "plots",
)
    ensure_output_dirs(data_dir, plots_dir)
    rows = NamedTuple[]

    scenario_id = 0
    for N in N_values, S in S_values, repairers in repairer_values
        scenario_id += 1
        crash_times = Float64[]
        queues = Float64[]
        utilizations = Float64[]

        for run_id in 1:runs
            result = simulate_ross_once(;
                N = N,
                S = S,
                repairers = repairers,
                mean_time_to_failure = mean_time_to_failure,
                mean_repair_time = mean_repair_time,
                seed = seed + 1000 * scenario_id + run_id,
            )
            push!(crash_times, result.crash_time)
            push!(queues, result.metrics.mean_repair_queue)
            push!(utilizations, result.metrics.repairer_utilization)
        end

        analytic = ross_analytic_crash_time(;
            N = N,
            S = S,
            repairers = repairers,
            mean_time_to_failure = mean_time_to_failure,
            mean_repair_time = mean_repair_time,
        )
        push!(
            rows,
            (
                N = Int(N),
                S = Int(S),
                repairers = Int(repairers),
                runs = Int(runs),
                mean_crash_time = mean(crash_times),
                std_crash_time = std(crash_times),
                analytic_crash_time = analytic,
                mean_repair_queue = mean(queues),
                repairer_utilization = mean(utilizations),
            ),
        )
    end

    scan = DataFrame(rows)
    CSV.write(joinpath(data_dir, "ross_parameter_scan.csv"), scan)

    base_n = N_values[min(2, length(N_values))]
    part_spares = filter(:N => ==(base_n), scan)
    p_spares = plot(; xlabel = "spares", ylabel = "crash time", title = "Ross crash time by spares")
    for repairers in repairer_values
        part = filter(:repairers => ==(repairers), part_spares)
        sort!(part, :S)
        plot!(p_spares, part.S, part.mean_crash_time; marker = :circle, label = "repairers=$(repairers)")
    end
    savefig(p_spares, joinpath(plots_dir, "ross_crash_time_by_spares.png"))

    base_repairers = repairer_values[1]
    p_n = plot(; xlabel = "N", ylabel = "crash time", title = "Ross crash time by N")
    for S in S_values
        part = filter([:S, :repairers] => (s, r) -> s == S && r == base_repairers, scan)
        sort!(part, :N)
        plot!(p_n, part.N, part.mean_crash_time; marker = :circle, label = "S=$(S)")
    end
    savefig(p_n, joinpath(plots_dir, "ross_crash_time_by_n.png"))

    p_rep = plot(; xlabel = "repairers", ylabel = "crash time", title = "Ross repairers comparison")
    for S in S_values
        part = filter([:N, :S] => (n, s) -> n == base_n && s == S, scan)
        sort!(part, :repairers)
        plot!(p_rep, part.repairers, part.mean_crash_time; marker = :circle, label = "S=$(S)")
    end
    savefig(p_rep, joinpath(plots_dir, "ross_repairers_comparison.png"))

    part_util = filter(:N => ==(base_n), scan)
    scenario_labels = ["S=$(row.S), R=$(row.repairers)" for row in eachrow(part_util)]
    p_util = bar(
        scenario_labels,
        part_util.repairer_utilization;
        label = false,
        ylabel = "utilization",
        title = "Ross utilization by scenario",
        xrotation = 45,
        bottom_margin = 8 * Plots.mm,
    )
    savefig(p_util, joinpath(plots_dir, "ross_repairer_utilization_by_scenario.png"))

    println("Ross parameter scan completed.")
    println("Saved data/ross_parameter_scan.csv")
    println("Saved plots/ross_crash_time_by_spares.png")
    println("Saved plots/ross_crash_time_by_n.png")
    println("Saved plots/ross_repairers_comparison.png")
    println("Saved plots/ross_repairer_utilization_by_scenario.png")

    return scan
end

end
