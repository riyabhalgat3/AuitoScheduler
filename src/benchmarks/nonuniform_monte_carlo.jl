module NonUniformMonteCarloBenchmark

using Random
using Statistics
using Base.Threads

export NonUniformMCConfig, run_nonuniform_monte_carlo

# ============================================================
# CONFIG
# ============================================================

struct NonUniformMCConfig
    n_samples::Int
    chunk_size::Int
    deadline_s::Float64
end

NonUniformMCConfig(; n_samples::Int, chunk_size::Int, deadline_s::Float64) =
    NonUniformMCConfig(n_samples, chunk_size, deadline_s)

# ============================================================
# NON-UNIFORM COST MODEL (STRESSED IMBALANCE)
# ============================================================

@inline function sample_work(x::Float64, y::Float64)
    r2 = x*x + y*y

    if r2 < 0.25
        return 1.0
    elseif r2 < 1.0
        acc = 0.0
        @inbounds for _ in 1:300
            acc += sqrt(r2)
        end
        return acc
    else
        # INTENTIONALLY HEAVY REGION (STRAGGLERS)
        acc = 0.0
        @inbounds for _ in 1:8000
            acc += log1p(r2)
        end
        return acc
    end
end

function execute_chunk(start_idx::Int, end_idx::Int)
    acc = 0.0
    for _ in start_idx:end_idx
        x, y = rand(), rand()
        acc += sample_work(x, y)
    end
    return acc
end

# ============================================================
# BENCHMARK (TAIL + DEADLINE AWARE)
# ============================================================

function run_nonuniform_monte_carlo(use_scheduler::Bool,
                                    cfg::NonUniformMCConfig;
                                    n_iterations::Int = 3,
                                    warmup::Int = 1)

    run_times = Float64[]
    thread_finish_times = Vector{Vector{Float64}}()
    deadline_misses = Int[]

    nthreads = Threads.nthreads()

    for iter in 1:(n_iterations + warmup)
        thread_times = fill(0.0, nthreads)
        t0 = time()

        if nthreads == 1
            execute_chunk(1, cfg.n_samples)
            thread_times[1] = time() - t0

        elseif use_scheduler
            tasks = Channel{Tuple{Int,Int}}(ceil(Int, cfg.n_samples / cfg.chunk_size))

            @async begin
                for i in 1:cfg.chunk_size:cfg.n_samples
                    put!(tasks, (i, min(i + cfg.chunk_size - 1, cfg.n_samples)))
                end
                close(tasks)
            end

            @sync for tid in 1:nthreads
                Threads.@spawn begin
                    t_start = time()
                    for (s, e) in tasks
                        execute_chunk(s, e)
                    end
                    thread_times[tid] = time() - t_start
                end
            end
        else
            per_thread = ceil(Int, cfg.n_samples / nthreads)

            @sync for tid in 1:nthreads
                Threads.@spawn begin
                    start = (tid - 1) * per_thread + 1
                    stop  = min(tid * per_thread, cfg.n_samples)
                    t_start = time()
                    if start <= stop
                        execute_chunk(start, stop)
                    end
                    thread_times[tid] = time() - t_start
                end
            end
        end

        elapsed = time() - t0

        if iter > warmup
            push!(run_times, elapsed)
            push!(thread_finish_times, copy(thread_times))
            misses = count(t -> t > cfg.deadline_s, thread_times)
            push!(deadline_misses, misses)
        end
    end

    all_thread_times = reduce(vcat, thread_finish_times)

    return Dict(
        "mean_time" => mean(run_times),
        "std_time"  => std(run_times),
        "p95"       => quantile(all_thread_times, 0.95),
        "p99"       => quantile(all_thread_times, 0.99),
        "max"       => maximum(all_thread_times),
        "deadline_miss_rate" => mean(deadline_misses) / nthreads,
        "thread_times" => thread_finish_times
    )
end

end # module
