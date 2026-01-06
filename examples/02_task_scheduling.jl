# examples/02_task_scheduling.jl
using AutoScheduler
using Printf

println("\n" * "="^80)
println("EXAMPLE 2: Task Scheduling")
println("="^80)
println()

# ============================================================================
# Part 1: Simple Task Scheduling
# ============================================================================

println("Part 1: Simple Task Scheduling")
println("-"^80)

# Define a simple task
tasks = [
    Task("data_processing", 2048, 60.0, :cpu_intensive, String[], nothing, 0.7)
]

println("Scheduling 1 task:")
println("  Task: data_processing")
println("  Memory: 2048 MB")
println("  Compute Intensity: 60.0")
println()

result = schedule(tasks, optimize_for=:energy, verbose=true)

println("\nResults:")
@printf("  Energy savings: %.1f%%\n", result.energy_savings_percent)
@printf("  Time savings: %.1f%%\n", result.time_savings_percent)
@printf("  Battery extension: %.1f minutes\n", result.battery_extension_minutes)
@printf("  Cost savings: \$%.4f\n", result.cost_savings_dollars)

# ============================================================================
# Part 2: Task with Dependencies
# ============================================================================

println("\n" * "="^80)
println("Part 2: Task Pipeline with Dependencies")
println("-"^80)

# Define tasks with dependencies
tasks = [
    Task("load_data", 1024, 30.0, :cpu_intensive, String[], nothing, 0.5),
    Task("preprocess", 2048, 50.0, :cpu_intensive, ["load_data"], nothing, 0.6),
    Task("train_model", 8192, 90.0, :gpu_intensive, ["preprocess"], 120.0, 0.9),
    Task("evaluate", 1024, 40.0, :cpu_intensive, ["train_model"], nothing, 0.7)
]

println("Scheduling pipeline with 4 tasks:")
for task in tasks
    deps_str = isempty(task.depends_on) ? "none" : join(task.depends_on, ", ")
    println("  $(task.id) (depends on: $deps_str)")
end
println()

result = schedule(tasks, optimize_for=:balanced, verbose=true)

println("\nResults:")
@printf("  Energy savings: %.1f%%\n", result.energy_savings_percent)
@printf("  Time savings: %.1f%%\n", result.time_savings_percent)
@printf("  Battery extension: %.1f minutes\n", result.battery_extension_minutes)

# ============================================================================
# Part 3: Different Optimization Strategies
# ============================================================================

println("\n" * "="^80)
println("Part 3: Comparing Optimization Strategies")
println("-"^80)

tasks = [
    Task("task1", 2048, 50.0, :cpu_intensive, String[], nothing, 0.6),
    Task("task2", 4096, 70.0, :cpu_intensive, ["task1"], nothing, 0.8),
    Task("task3", 1024, 40.0, :cpu_intensive, ["task1"], nothing, 0.5)
]

println("Testing 3 optimization strategies:")
println()

# Energy optimization
println("1. Energy Optimization:")
energy_result = schedule(tasks, optimize_for=:energy, verbose=false)
@printf("   Energy savings: %.1f%%\n", energy_result.energy_savings_percent)
@printf("   Time savings: %.1f%%\n", energy_result.time_savings_percent)

# Performance optimization
println("\n2. Performance Optimization:")
perf_result = schedule(tasks, optimize_for=:performance, verbose=false)
@printf("   Energy savings: %.1f%%\n", perf_result.energy_savings_percent)
@printf("   Time savings: %.1f%%\n", perf_result.time_savings_percent)

# Balanced optimization
println("\n3. Balanced Optimization:")
balanced_result = schedule(tasks, optimize_for=:balanced, verbose=false)
@printf("   Energy savings: %.1f%%\n", balanced_result.energy_savings_percent)
@printf("   Time savings: %.1f%%\n", balanced_result.time_savings_percent)

# ============================================================================
# Part 4: Tasks with Deadlines
# ============================================================================

println("\n" * "="^80)
println("Part 4: Scheduling with Deadlines")
println("-"^80)

tasks = [
    Task("urgent_task", 1024, 50.0, :cpu_intensive, String[], 10.0, 1.0),
    Task("normal_task", 2048, 60.0, :cpu_intensive, String[], 60.0, 0.6),
    Task("low_priority", 512, 30.0, :cpu_intensive, String[], 120.0, 0.3)
]

println("Tasks with different deadlines and priorities:")
for task in tasks
    deadline_str = task.deadline === nothing ? "none" : "$(task.deadline)s"
    println("  $(task.id): priority=$(task.priority), deadline=$deadline_str")
end
println()

result = schedule(tasks, optimize_for=:balanced, verbose=true)

println("\nResults:")
@printf("  Energy savings: %.1f%%\n", result.energy_savings_percent)
@printf("  Time savings: %.1f%%\n", result.time_savings_percent)

# ============================================================================
# Part 5: Mixed Workload (CPU, GPU, Memory)
# ============================================================================

println("\n" * "="^80)
println("Part 5: Mixed Workload Types")
println("-"^80)

tasks = [
    Task("cpu_task", 1024, 70.0, :cpu_intensive, String[], nothing, 0.7),
    Task("gpu_task", 8192, 90.0, :gpu_intensive, String[], nothing, 0.9),
    Task("memory_task", 16384, 40.0, :memory_intensive, String[], nothing, 0.6),
    Task("io_task", 512, 20.0, :io_intensive, String[], nothing, 0.4)
]

println("Scheduling mixed workload:")
for task in tasks
    println("  $(task.id): $(task.task_type)")
end
println()

result = schedule(tasks, optimize_for=:balanced, power_budget=150.0, verbose=true)

println("\nResults:")
@printf("  Energy savings: %.1f%%\n", result.energy_savings_percent)
@printf("  Time savings: %.1f%%\n", result.time_savings_percent)
@printf("  Battery extension: %.1f minutes\n", result.battery_extension_minutes)
@printf("  Cost savings: \$%.4f\n", result.cost_savings_dollars)

# ============================================================================
# Part 6: Power Budget Constraint
# ============================================================================

println("\n" * "="^80)
println("Part 6: Scheduling with Power Budget")
println("-"^80)

tasks = [
    Task("task1", 2048, 60.0, :cpu_intensive, String[], nothing, 0.7),
    Task("task2", 4096, 80.0, :cpu_intensive, ["task1"], nothing, 0.8)
]

println("Testing different power budgets:")
println()

for budget in [80.0, 120.0, 200.0]
    println("Power budget: $(budget)W")
    result = schedule(tasks, power_budget=budget, verbose=false)
    @printf("  Energy savings: %.1f%%\n", result.energy_savings_percent)
    @printf("  Time savings: %.1f%%\n\n", result.time_savings_percent)
end

println("="^80)
println("Example Complete!")
println("="^80)