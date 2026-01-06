# benchmarks/run_all.jl
using AutoScheduler
using AutoScheduler.BenchmarkCLI

println("Running all benchmarks...")
BenchmarkCLI.run_all_benchmarks(
    iterations=5,
    save_results=true,
    output_dir="benchmarks/results"
)
