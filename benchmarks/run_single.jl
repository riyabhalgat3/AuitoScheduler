# benchmarks/run_single.jl
using AutoScheduler
using AutoScheduler.BenchmarkCLI

if length(ARGS) < 1
    println("Usage: julia run_single.jl BENCHMARK_ID [iterations]")
    println("\nAvailable benchmarks:")
    BenchmarkCLI.list_benchmarks()
    exit(1)
end

benchmark_id = ARGS[1]
iterations = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 5

BenchmarkCLI.run_benchmark_cli(
    benchmark_id,
    iterations=iterations,
    compare=true,
    save_results=true
)