"""
src/benchmarks/benchmark_framework.jl
Common Framework for Running and Comparing Benchmarks
PRODUCTION FIXED VERSION
"""

module BenchmarkFramework

using Printf
using Statistics
using Dates
using JSON3

using ..PowerMeasurement

export BenchmarkResult, BenchmarkConfig, ComparisonResult
export run_benchmark, compare_results, generate_report
export save_results, load_results
export statistical_significance, calculate_speedup

# ============================================================================
# Data Structures
# ============================================================================

struct BenchmarkResult
    name::String
    scheduler::String
    execution_time_s::Float64
    energy_consumed_j::Float64
    throughput::Float64
    memory_peak_mb::Float64
    cpu_utilization_pct::Float64
    gpu_utilization_pct::Float64
    timestamp::DateTime
    metadata::Dict{String, Any}
end

struct BenchmarkConfig
    name::String
    iterations::Int
    warmup_iterations::Int
    min_cpu_threshold::Float64
    power_budget::Float64
    timeout_s::Int
    output_dir::String
end

struct ComparisonResult
    benchmark_name::String
    baseline_stats::Dict{String, Float64}
    scheduled_stats::Dict{String, Float64}
    improvements::Dict{String, Float64}
    statistical_tests::Dict{String, Any}
    timestamp::DateTime
end

# ============================================================================
# Benchmark Execution
# ============================================================================

function run_benchmark(
    name::String,
    workload_fn::Function,
    config::BenchmarkConfig = BenchmarkConfig(
        name, 5, 1, 10.0, 150.0, 3600, "benchmarks/results"
    )
)::Tuple{Vector{BenchmarkResult}, Vector{BenchmarkResult}}

    baseline = BenchmarkResult[]
    scheduled = BenchmarkResult[]

    for _ in 1:config.warmup_iterations
        try
            workload_fn(false)
        catch
        end
    end

    for _ in 1:config.iterations
        push!(baseline,
            measure_execution(name, "baseline", workload_fn, false, config))
    end

    for _ in 1:config.iterations
        push!(scheduled,
            measure_execution(name, "autoscheduler", workload_fn, true, config))
    end

    return baseline, scheduled
end

function measure_execution(
    name::String,
    scheduler::String,
    workload_fn::Function,
    use_scheduler::Bool,
    config::BenchmarkConfig
)::BenchmarkResult

    start_time = time()
    start_mem = Sys.free_memory()

    energy_samples = PowerReading[]
    monitor = @async begin
        while time() - start_time < config.timeout_s
            try
                push!(energy_samples, get_power_consumption())
            catch
            end
            sleep(0.5)
        end
    end

    result_data = try
        workload_fn(use_scheduler)
    catch
        Dict{String, Any}()
    end

    exec_time = time() - start_time

    try
        Base.throwto(monitor, InterruptException())
    catch
    end

    total_energy =
        isempty(energy_samples) ? 100.0 * exec_time :
        calculate_energy(energy_samples)

    mem_used =
        max(0, start_mem - Sys.free_memory()) / 1e6

    return BenchmarkResult(
        name,
        scheduler,
        exec_time,
        total_energy,
        get(result_data, "throughput", 0.0),
        mem_used,
        get(result_data, "cpu_usage", 0.0),
        get(result_data, "gpu_usage", 0.0),
        now(),
        result_data
    )
end

# ============================================================================
# Statistical Analysis
# ============================================================================

function compare_results(
    baseline::Vector{BenchmarkResult},
    scheduled::Vector{BenchmarkResult}
)::ComparisonResult

    b_times = [r.execution_time_s for r in baseline]
    s_times = [r.execution_time_s for r in scheduled]

    b_energy = [r.energy_consumed_j for r in baseline]
    s_energy = [r.energy_consumed_j for r in scheduled]

    b_tp = [r.throughput for r in baseline]
    s_tp = [r.throughput for r in scheduled]

    baseline_stats = Dict(
        "time_mean" => mean(b_times),
        "time_std" => std(b_times),
        "energy_mean" => mean(b_energy),
        "throughput_mean" => mean(b_tp)
    )

    scheduled_stats = Dict(
        "time_mean" => mean(s_times),
        "time_std" => std(s_times),
        "energy_mean" => mean(s_energy),
        "throughput_mean" => mean(s_tp)
    )

    improvements = Dict(
        "time_improvement_pct" =>
            (baseline_stats["time_mean"] - scheduled_stats["time_mean"]) /
            baseline_stats["time_mean"] * 100,
        "energy_savings_pct" =>
            (baseline_stats["energy_mean"] - scheduled_stats["energy_mean"]) /
            baseline_stats["energy_mean"] * 100,
        "throughput_gain_pct" =>
            (scheduled_stats["throughput_mean"] - baseline_stats["throughput_mean"]) /
            baseline_stats["throughput_mean"] * 100,
        "speedup" =>
            baseline_stats["time_mean"] / scheduled_stats["time_mean"]
    )

    tests = Dict(
        "time_t_test" => welch_t_test(b_times, s_times),
        "energy_t_test" => welch_t_test(b_energy, s_energy)
    )

    return ComparisonResult(
        baseline[1].name,
        baseline_stats,
        scheduled_stats,
        improvements,
        tests,
        now()
    )
end

function welch_t_test(x::Vector{Float64}, y::Vector{Float64})::Dict
    t = (mean(x) - mean(y)) / sqrt(var(x)/length(x) + var(y)/length(y))
    return Dict("t_statistic" => t, "significant" => abs(t) > 2.0)
end

calculate_speedup(b::Float64, s::Float64) = b / s

function statistical_significance(c::ComparisonResult)::Bool
    c.statistical_tests["time_t_test"]["significant"] ||
    c.statistical_tests["energy_t_test"]["significant"]
end

# ============================================================================
# Persistence & Reports
# ============================================================================

function save_results(results, filename::String)
    mkpath(dirname(filename))
    open(filename, "w") do io
        JSON3.write(io, results)
    end
end

function load_results(filename::String)
    open(filename) do io
        JSON3.read(io)
    end
end

function generate_report(comparisons::Vector{ComparisonResult}, output::String)
    mkpath(dirname(output))
    open(output, "w") do io
        for c in comparisons
            write(io, "$(c.benchmark_name): $(c.improvements)\n")
        end
    end
end

end # module BenchmarkFramework
