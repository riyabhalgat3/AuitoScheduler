#!/usr/bin/env julia
"""
AutoScheduler Research Demonstration
Shows system information, task allocation, and scheduling results
"""

using AutoScheduler
using Printf

println("="^80)
println("AutoScheduler Research Demonstration")
println("="^80)
println()

# ============================================================================
# 1. SYSTEM INFORMATION
# ============================================================================

println("SYSTEM INFORMATION")
println("-"^80)

metrics = get_real_metrics()
println("Platform: $(metrics.platform)")
println("Architecture: $(Sys.ARCH)")
println("Total CPU Cores: $(Sys.CPU_THREADS)")
println("Physical Cores: $(Sys.CPU_THREADS ÷ 2)")
println()

println("Memory:")
@printf("  Total: %.2f GB\n", metrics.memory_total_bytes / 1024^3)
@printf("  Used: %.2f GB (%.1f%%)\n",
        metrics.memory_used_bytes / 1024^3,
        (metrics.memory_used_bytes / metrics.memory_total_bytes) * 100)
println()

println("CPU Usage Per Core:")
for (core_id, usage) in sort(collect(metrics.cpu_usage_per_core))
    @printf("  Core %2d: %5.1f%%\n", core_id, usage)
end
println()

println("Load Average:")
@printf("  1 min:  %.2f\n", metrics.load_average_1min)
@printf("  5 min:  %.2f\n", metrics.load_average_5min)
@printf("  15 min: %.2f\n", metrics.load_average_15min)
println()

gpus = get_gpu_info()
if !isempty(gpus)
    println("GPU Information:")
    for gpu in gpus
        println("  GPU $(gpu.id): $(gpu.name)")
        @printf("    Vendor: %s\n", gpu.vendor)
        @printf("    Memory: %.2f GB / %.2f GB\n",
                gpu.memory_used_bytes / 1024^3,
                gpu.memory_total_bytes / 1024^3)
        @printf("    Utilization: %.1f%%\n", gpu.utilization_percent)
    end
    println()
else
    println("GPU: No GPU detected\n")
end

# ============================================================================
# 2. TASK SCHEDULING DEMONSTRATION
# ============================================================================

println("="^80)
println("TASK SCHEDULING DEMONSTRATION")
println("="^80)
println()

const ASTask = AutoScheduler.SchedulerCore.Task

tasks = [
    ASTask("data_load", 1024, 30.0, :io_intensive, String[], nothing, 0.5),
    ASTask("preprocessing", 2048, 60.0, :cpu_intensive, ["data_load"], nothing, 0.7),
    ASTask("model_training", 8192, 90.0, :gpu_intensive, ["preprocessing"], nothing, 0.9),
    ASTask("evaluation", 1024, 40.0, :cpu_intensive, ["model_training"], nothing, 0.6),
    ASTask("save_results", 512, 20.0, :io_intensive, ["evaluation"], nothing, 0.4),
]

println("Tasks to Schedule:")
println("-"^80)
for (i, task) in enumerate(tasks)
    println("Task $i: $(task.id)")
    @printf("  Memory: %d MB, Compute: %.1f, Type: %s, Priority: %.1f\n",
            task.memory_mb, task.compute_intensity, task.task_type, task.priority)
    if !isempty(task.depends_on)
        println("  Dependencies: $(join(task.depends_on, ", "))")
    end
end
println()

println("="^80)
println("SCHEDULING RESULTS")
println("="^80)
println()

for strategy in [:energy, :performance, :balanced]
    println("Strategy: $(uppercase(string(strategy)))")
    println("-"^80)

    result = AutoScheduler.schedule(
        tasks;
        optimize_for = strategy,
        verbose = false
    )

    @printf("  Energy Savings: %.1f%%\n", result.energy_savings_percent)
    @printf("  Time Savings: %.1f%%\n", result.time_savings_percent)
    @printf("  Battery Extension: %.1f minutes\n", result.battery_extension_minutes)
    @printf("  Cost Savings: \$%.2f\n", result.cost_savings_dollars)
    @printf("  Baseline Energy: %.1f Joules\n", result.baseline_energy)
    @printf("  Baseline Time: %.1f seconds\n", result.baseline_time)
    println()
end

# ============================================================================
# 3. BENCHMARK RESULTS
# ============================================================================

println("="^80)
println("BENCHMARK RESULTS")
println("="^80)
println()

# ---------------- ResNet ----------------

println("ResNet-50 Benchmark:")
println("-"^80)
using AutoScheduler.ResNetBenchmark

res_cfg = ResNetConfig(batch_size=4, num_batches=2, use_gpu=false)

res_base = run_resnet_benchmark(false, res_cfg)
res_sched = run_resnet_benchmark(true, res_cfg)

@printf("  Baseline Throughput: %.2f images/sec\n", res_base["throughput"])
@printf("  Scheduled Throughput: %.2f images/sec\n", res_sched["throughput"])
@printf("  Speedup: %.2fx\n",
        res_sched["throughput"] / res_base["throughput"])
println()

# ---------------- Monte Carlo ----------------

println("Monte Carlo π Estimation:")
println("-"^80)
using AutoScheduler.MonteCarloBenchmark

mc_cfg = MonteCarloConfig(n_samples=1_000_000, n_threads=4)

mc_base = run_monte_carlo_benchmark(false, mc_cfg)
mc_sched = run_monte_carlo_benchmark(true, mc_cfg)

pi_base = mc_base["pi_estimate"]
pi_sched = mc_sched["pi_estimate"]

@printf("  Baseline π estimate: %.6f (error: %.6f)\n",
        pi_base, abs(pi_base - π))
@printf("  Scheduled π estimate: %.6f (error: %.6f)\n",
        pi_sched, abs(pi_sched - π))
@printf("  Baseline Throughput: %.2e samples/sec\n", mc_base["throughput"])
@printf("  Scheduled Throughput: %.2e samples/sec\n", mc_sched["throughput"])
@printf("  Speedup: %.2fx\n",
        mc_sched["throughput"] / mc_base["throughput"])
println()
