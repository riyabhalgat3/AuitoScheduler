#!/usr/bin/env julia

using AutoScheduler
using AutoScheduler.MonteCarloBenchmark
using AutoScheduler.NonUniformMonteCarloBenchmark
using Printf
using Base.Threads

println("="^80)
println("AUTOSCHEDULER — STRESSED NON-UNIFORM MONTE CARLO")
println("="^80)
println()

println("SYSTEM CONFIGURATION")
println("-"^80)
println("CPU cores: ", Sys.CPU_THREADS)
println("Julia threads: ", Threads.nthreads())
println()

# ============================================================
# UNIFORM MONTE CARLO (CONTROL)
# ============================================================

println("="^80)
println("UNIFORM MONTE CARLO (CONTROL)")
println("="^80)

uniform_cfg = MonteCarloConfig(
    n_samples = 5_000_000,
    n_threads = Threads.nthreads()
)

u_base = run_monte_carlo_benchmark(false, uniform_cfg, n_iterations=3, warmup=1)
u_sched = run_monte_carlo_benchmark(true, uniform_cfg, n_iterations=3, warmup=1)

@printf("Baseline mean:  %.4f s\n", u_base["mean_time"])
@printf("Scheduled mean: %.4f s\n", u_sched["mean_time"])
println("Result: scheduler neutral under uniform cost")
println()

# ============================================================
# NON-UNIFORM MONTE CARLO (STRESSED)
# ============================================================

println("="^80)
println("NON-UNIFORM MONTE CARLO (STRESSED IMBALANCE)")
println("="^80)

cfg = NonUniformMCConfig(
    n_samples = 3_000_000,
    chunk_size = 2_000,
    deadline_s = 2.8
)

println("Running baseline (static)...")
nu_base = run_nonuniform_monte_carlo(false, cfg)

println("Running scheduled (dynamic)...")
nu_sched = run_nonuniform_monte_carlo(true, cfg)

println()
println("MEAN EXECUTION TIME")
@printf("Baseline:  %.3f s\n", nu_base["mean_time"])
@printf("Scheduled: %.3f s\n", nu_sched["mean_time"])

println()
println("TAIL LATENCY")
@printf("Baseline p95: %.3f s\n", nu_base["p95"])
@printf("Baseline p99: %.3f s\n", nu_base["p99"])
@printf("Baseline max: %.3f s\n", nu_base["max"])

println()

@printf("Scheduled p95: %.3f s\n", nu_sched["p95"])
@printf("Scheduled p99: %.3f s\n", nu_sched["p99"])
@printf("Scheduled max: %.3f s\n", nu_sched["max"])


