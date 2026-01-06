"""
src/cli/benchmark.jl
CLI Benchmark Runner
PRODUCTION VERSION - 400 lines
"""

module BenchmarkCLI

using Printf
using Dates

export run_benchmark_cli, list_benchmarks

using ..BenchmarkFramework
using ..ResNetBenchmark
using ..MonteCarloBenchmark
using ..VideoEncodeBenchmark
using ..DNASequenceBenchmark
using ..MapReduceBenchmark

# ============================================================================
# Available Benchmarks
# ============================================================================

const AVAILABLE_BENCHMARKS = Dict(
    "resnet" => (
        name = "ResNet-50 Training",
        description = "Deep learning training workload",
        fn = run_resnet_benchmark
    ),
    "montecarlo" => (
        name = "Monte Carlo π Estimation",
        description = "Scientific computing workload",
        fn = run_monte_carlo_benchmark
    ),
    "video" => (
        name = "Video Encoding",
        description = "Video processing workload",
        fn = run_video_encode_benchmark
    ),
    "dna" => (
        name = "DNA Sequence Alignment",
        description = "Bioinformatics workload",
        fn = run_dna_sequence_benchmark
    ),
    "mapreduce" => (
        name = "MapReduce Word Count",
        description = "Distributed computing workload",
        fn = run_mapreduce_benchmark
    )
)

# ============================================================================
# CLI Functions
# ============================================================================

"""
    list_benchmarks()

List all available benchmarks.
"""
function list_benchmarks()
    println("\n" * "="^70)
    println("AVAILABLE BENCHMARKS")
    println("="^70)
    println()
    
    for (id, info) in sort(collect(AVAILABLE_BENCHMARKS))
        println("  $id")
        println("    Name: $(info.name)")
        println("    Description: $(info.description)")
        println()
    end
    
    println("Usage:")
    println("  julia --project=. -e 'using AutoScheduler; BenchmarkCLI.run_benchmark_cli(\"BENCHMARK_ID\")'")
    println()
end

"""
    run_benchmark_cli(benchmark_id::String; kwargs...)

Run a specific benchmark from CLI.

# Arguments
- `benchmark_id::String` - Benchmark identifier
- `iterations::Int` - Number of iterations (default: 5)
- `compare::Bool` - Compare with baseline (default: true)
- `save_results::Bool` - Save results to file (default: true)
- `output_dir::String` - Output directory (default: "benchmarks/results")
"""
function run_benchmark_cli(
    benchmark_id::String;
    iterations::Int=5,
    compare::Bool=true,
    save_results::Bool=true,
    output_dir::String="benchmarks/results"
)
    
    # Validate benchmark ID
    if !haskey(AVAILABLE_BENCHMARKS, benchmark_id)
        @error "Unknown benchmark: $benchmark_id"
        println("\nAvailable benchmarks:")
        list_benchmarks()
        return
    end
    
    info = AVAILABLE_BENCHMARKS[benchmark_id]
    
    println("\n" * "="^80)
    println("RUNNING BENCHMARK: $(info.name)")
    println("="^80)
    println("Description: $(info.description)")
    println("Iterations: $iterations")
    println("Compare with baseline: $compare")
    println("="^80)
    println()
    
    # Create benchmark config
    config = BenchmarkConfig(
        benchmark_id,
        iterations,
        1,  # warmup iterations
        10.0,  # min CPU threshold
        150.0,  # power budget
        3600,  # timeout
        output_dir
    )
    
    # Run benchmark
    try
        baseline_results, scheduled_results = run_benchmark(
            benchmark_id,
            info.fn,
            config
        )
        
        # Compare results
        if compare && !isempty(baseline_results) && !isempty(scheduled_results)
            comparison = compare_results(baseline_results, scheduled_results)
            print_comparison(comparison)
            
            # Save results
            if save_results
                timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
                result_dir = joinpath(output_dir, timestamp)
                mkpath(result_dir)
                
                # Save comparison
                report_file = joinpath(result_dir, "report.md")
                generate_report([comparison], report_file)
                
                # Save raw results
                results_file = joinpath(result_dir, "results.json")
                BenchmarkFramework.save_results((baseline_results, scheduled_results), results_file)
                
                println("\nResults saved to: $result_dir")
            end
        end
        
    catch e
        @error "Benchmark failed" exception=e
        rethrow(e)
    end
end

"""
    run_all_benchmarks(; kwargs...)

Run all available benchmarks.
"""
function run_all_benchmarks(;
    iterations::Int=5,
    save_results::Bool=true,
    output_dir::String="benchmarks/results"
)
    
    println("\n" * "="^80)
    println("RUNNING ALL BENCHMARKS")
    println("="^80)
    println("Total benchmarks: $(length(AVAILABLE_BENCHMARKS))")
    println("Iterations per benchmark: $iterations")
    println("="^80)
    println()
    
    all_comparisons = ComparisonResult[]
    
    for (i, (id, info)) in enumerate(sort(collect(AVAILABLE_BENCHMARKS)))
        println("\n[$i/$(length(AVAILABLE_BENCHMARKS))] $(info.name)")
        println("-"^80)
        
        try
            # Run benchmark
            config = BenchmarkConfig(id, iterations, 1, 10.0, 150.0, 3600, output_dir)
            baseline_results, scheduled_results = run_benchmark(id, info.fn, config)
            
            # Compare
            if !isempty(baseline_results) && !isempty(scheduled_results)
                comparison = compare_results(baseline_results, scheduled_results)
                push!(all_comparisons, comparison)
                
                # Print quick summary
                @printf("  Time improvement: %.1f%%\n", comparison.improvements["time_improvement_pct"])
                @printf("  Energy savings: %.1f%%\n", comparison.improvements["energy_savings_pct"])
            end
            
        catch e
            @error "Benchmark $id failed" exception=e
        end
    end
    
    # Generate combined report
    if save_results && !isempty(all_comparisons)
        timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
        result_dir = joinpath(output_dir, timestamp)
        mkpath(result_dir)
        
        report_file = joinpath(result_dir, "all_benchmarks_report.md")
        generate_report(all_comparisons, report_file)
        
        println("\n" * "="^80)
        println("ALL BENCHMARKS COMPLETED")
        println("="^80)
        println("Results saved to: $result_dir")
        println("Report: $report_file")
        println("="^80)
    end
end

# ============================================================================
# Display Functions
# ============================================================================

function print_comparison(comparison::ComparisonResult)
    println("\n" * "="^80)
    println("COMPARISON RESULTS: $(comparison.benchmark_name)")
    println("="^80)
    println()
    
    # Baseline stats
    println("Baseline:")
    @printf("  Execution Time: %.3f ± %.3f s\n",
            comparison.baseline_stats["time_mean"],
            comparison.baseline_stats["time_std"])
    @printf("  Energy: %.2f ± %.2f J\n",
            comparison.baseline_stats["energy_mean"],
            comparison.baseline_stats["energy_std"])
    @printf("  Throughput: %.2f ops/s\n",
            comparison.baseline_stats["throughput_mean"])
    println()
    
    # Scheduled stats
    println("With AutoScheduler:")
    @printf("  Execution Time: %.3f ± %.3f s\n",
            comparison.scheduled_stats["time_mean"],
            comparison.scheduled_stats["time_std"])
    @printf("  Energy: %.2f ± %.2f J\n",
            comparison.scheduled_stats["energy_mean"],
            comparison.scheduled_stats["energy_std"])
    @printf("  Throughput: %.2f ops/s\n",
            comparison.scheduled_stats["throughput_mean"])
    println()
    
    # Improvements
    println("Improvements:")
    @printf("  Time: %+.1f%%\n", comparison.improvements["time_improvement_pct"])
    @printf("  Energy: %+.1f%%\n", comparison.improvements["energy_savings_pct"])
    @printf("  Throughput: %+.1f%%\n", comparison.improvements["throughput_gain_pct"])
    @printf("  Speedup: %.2fx\n", comparison.improvements["speedup"])
    println()
    
    # Statistical significance
    time_test = comparison.statistical_tests["time_t_test"]
    println("Statistical Analysis:")
    @printf("  t-statistic: %.3f\n", time_test["t_statistic"])
    @printf("  Significant: %s\n", time_test["significant"] ? "Yes ✓" : "No")
    println()
    
    println("="^80)
end

end # module BenchmarkCLI