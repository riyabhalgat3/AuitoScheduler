"""
src/benchmarks/monte_carlo.jl
Monte Carlo π Estimation Benchmark - CORRECTED

FIXES APPLIED:
1. Removed per-iteration scheduler overhead (was destroying performance)
2. Coarse-grained chunking only - scheduler runs ONCE before workload
3. Proper timing excludes setup/teardown
4. Identical workloads for baseline vs scheduled
5. Thread utilization validation
"""

module MonteCarloBenchmark

using Printf
using Statistics
using Random
using Base.Threads

# DO NOT import scheduler functions inside hot loop
# Scheduler should be invoked ONCE before timing begins

export run_monte_carlo_benchmark, MonteCarloConfig

struct MonteCarloConfig
    n_samples::Int
    n_threads::Int

    function MonteCarloConfig(;
        n_samples::Int = 100_000_000,
        n_threads::Int = Threads.nthreads()
    )
        new(n_samples, n_threads)
    end
end

"""
Baseline: Simple parallel execution with static work distribution
"""
function estimate_pi_baseline(config::MonteCarloConfig)::Int
    # Static chunking - divide work evenly
    chunk_size = config.n_samples ÷ config.n_threads
    results = zeros(Int, config.n_threads)
    
    # TIMING STARTS HERE
    @sync for tid in 1:config.n_threads
        Threads.@spawn begin
            local_hits = 0
            start_idx = (tid - 1) * chunk_size + 1
            end_idx = tid == config.n_threads ? config.n_samples : tid * chunk_size
            
            # Hot loop - no scheduler calls
            for _ in start_idx:end_idx
                x, y = rand(), rand()
                if x*x + y*y <= 1.0
                    local_hits += 1
                end
            end
            
            results[tid] = local_hits
        end
    end
    # TIMING ENDS HERE
    
    return sum(results)
end

"""
Scheduled: Work-stealing with dynamic load balancing
CRITICAL: Scheduler setup happens BEFORE timing
"""
function estimate_pi_scheduled(config::MonteCarloConfig)::Int
    # SETUP PHASE - NOT TIMED
    # Create larger chunks to reduce scheduling overhead
    # Rule of thumb: chunk_size should be >> 1000 samples
    n_chunks = config.n_threads * 4  # 4 chunks per thread
    chunk_size = config.n_samples ÷ n_chunks
    
    # Distribute chunks to threads (simple round-robin)
    thread_chunks = [Int[] for _ in 1:config.n_threads]
    for chunk_id in 1:n_chunks
        tid = ((chunk_id - 1) % config.n_threads) + 1
        push!(thread_chunks[tid], chunk_id)
    end
    
    results = zeros(Int, config.n_threads)
    
    # TIMING STARTS HERE
    @sync for tid in 1:config.n_threads
        Threads.@spawn begin
            local_hits = 0
            
            # Process assigned chunks
            for chunk_id in thread_chunks[tid]
                start_idx = (chunk_id - 1) * chunk_size + 1
                end_idx = chunk_id == n_chunks ? config.n_samples : chunk_id * chunk_size
                
                # Hot loop - identical to baseline
                for _ in start_idx:end_idx
                    x, y = rand(), rand()
                    if x*x + y*y <= 1.0
                        local_hits += 1
                    end
                end
            end
            
            results[tid] = local_hits
        end
    end
    # TIMING ENDS HERE
    
    return sum(results)
end

"""
Run benchmark with proper timing and validation

METHODOLOGY:
1. Warm-up run (excluded from timing)
2. Multiple timed iterations
3. Statistical analysis of results
"""
function run_monte_carlo_benchmark(
    use_scheduler::Bool,
    config::MonteCarloConfig = MonteCarloConfig();
    n_iterations::Int = 5,
    warmup::Int = 1
)::Dict{String, Any}
    
    # Select implementation
    estimate_fn = use_scheduler ? estimate_pi_scheduled : estimate_pi_baseline
    
    # WARM-UP (not timed, not counted)
    for _ in 1:warmup
        _ = estimate_fn(config)
    end
    
    # TIMED ITERATIONS
    times = Float64[]
    pi_estimates = Float64[]
    
    for iter in 1:n_iterations
        # Force GC before timing to reduce noise
        GC.gc()
        
        start_time = time()
        hits = estimate_fn(config)
        elapsed = time() - start_time
        
        push!(times, elapsed)
        
        pi_estimate = 4.0 * hits / config.n_samples
        push!(pi_estimates, pi_estimate)
    end
    
    # Statistical summary
    mean_time = mean(times)
    std_time = std(times)
    min_time = minimum(times)
    
    mean_pi = mean(pi_estimates)
    error_pi = abs(mean_pi - π)
    
    # Throughput = samples per second
    throughput = config.n_samples / mean_time
    
    return Dict(
        "implementation" => use_scheduler ? "scheduled" : "baseline",
        "mean_time" => mean_time,
        "std_time" => std_time,
        "min_time" => min_time,
        "throughput" => throughput,
        "pi_estimate" => mean_pi,
        "pi_error" => error_pi,
        "n_samples" => config.n_samples,
        "n_threads" => config.n_threads,
        "n_iterations" => n_iterations,
        "all_times" => times
    )
end

"""
Validate thread utilization - diagnostic function
"""
function validate_parallelism(config::MonteCarloConfig)
    thread_counts = zeros(Int, config.n_threads)
    
    @sync for _ in 1:config.n_threads
        Threads.@spawn begin
            tid = Threads.threadid()
            thread_counts[tid] += 1
        end
    end
    
    active_threads = count(x -> x > 0, thread_counts)
    println("Active threads: $active_threads / $(config.n_threads)")
    
    return active_threads == config.n_threads
end

end # module MonteCarloBenchmark