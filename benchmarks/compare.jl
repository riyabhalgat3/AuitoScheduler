# benchmarks/compare.jl
using AutoScheduler
using AutoScheduler.BenchmarkFramework
using Printf

if length(ARGS) < 2
    println("Usage: julia compare.jl RESULT_DIR1 RESULT_DIR2")
    exit(1)
end

dir1, dir2 = ARGS[1], ARGS[2]

println("Comparing benchmark results:")
println("  Baseline: $dir1")
println("  New: $dir2")
println()

# Load results
results1 = BenchmarkFramework.load_results(joinpath(dir1, "results.json"))
results2 = BenchmarkFramework.load_results(joinpath(dir2, "results.json"))

# Compare
comparison = BenchmarkFramework.compare_results(results1[1], results2[1])

println("Differences:")
@printf("  Time: %+.1f%%\n", comparison.improvements["time_improvement_pct"])
@printf("  Energy: %+.1f%%\n", comparison.improvements["energy_savings_pct"])
@printf("  Speedup: %.2fx\n", comparison.improvements["speedup"])