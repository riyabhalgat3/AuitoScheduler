# examples/07_full_workflow.jl
using AutoScheduler
using Printf

println("\n" * "="^80)
println("EXAMPLE 7: Complete Workflow")
println("="^80)
println()
println("This example demonstrates a complete end-to-end workflow:")
println("  1. System assessment")
println("  2. Workload definition")
println("  3. Task scheduling")
println("  4. Live monitoring")
println("  5. Results analysis")
println()

# ============================================================================
# Step 1: System Assessment
# ============================================================================

println("="^80)
println("STEP 1: System Assessment")
println("="^80)
println()

println("Collecting system information...")
metrics = get_real_metrics()
gpus = get_gpu_info()
processes = get_running_processes(5.0)

println("System Configuration:")
@printf("  Platform: %s (%s)\n", metrics.platform, metrics.architecture)
@printf("  CPU Cores: %d\n", Sys.CPU_THREADS)
@printf("  Total Memory: %.2f GB\n", metrics.memory_total_bytes / 1e9)
@printf("  GPUs: %d\n", length(gpus))
println()

println("Current State:")
@printf("  CPU Usage: %.1f%%\n", metrics.total_cpu_usage)
@printf("  Memory Usage: %.1f%%\n", 
        100 * metrics.memory_used_bytes / metrics.memory_total_bytes)
@printf("  Load Average: %.2f\n", metrics.load_average_1min)
@printf("  Active Processes (>5%% CPU): %d\n", length(processes))

if metrics.temperature_celsius !== nothing
    @printf("  Temperature: %.1f°C\n", metrics.temperature_celsius)
end

if !isempty(gpus)
    println("\nGPU Status:")
    for gpu in gpus
        @printf("  GPU %d (%s): %.1f%% utilization\n",
                gpu.id, gpu.name, gpu.utilization_percent)
    end
end

# System capability assessment
println("\nCapability Assessment:")
has_gpu = !isempty(gpus)
has_high_memory = metrics.memory_total_bytes > 16e9
has_many_cores = Sys.CPU_THREADS >= 8

println("  GPU Available: $(has_gpu ? "Yes ✓" : "No")")
println("  High Memory (>16GB): $(has_high_memory ? "Yes ✓" : "No")")
println("  Many Cores (≥8): $(has_many_cores ? "Yes ✓" : "No")")

# ============================================================================
# Step 2: Workload Definition
# ============================================================================

println("\n" * "="^80)
println("STEP 2: Workload Definition")
println("="^80)
println()

println("Defining a machine learning training pipeline...")

# Define workflow based on system capabilities
tasks = []

# Stage 1: Data loading
push!(tasks, Task(
    "load_data",
    memory_mb = 2048,
    compute_intensity = 30.0,
    task_type = :cpu_intensive,
    depends_on = String[],
    deadline = nothing,
    priority = 0.5
))

# Stage 2: Preprocessing
push!(tasks, Task(
    "preprocess",
    memory_mb = 4096,
    compute_intensity = 50.0,
    task_type = :cpu_intensive,
    depends_on = ["load_data"],
    deadline = nothing,
    priority = 0.6
))

# Stage 3: Feature extraction
push!(tasks, Task(
    "feature_extraction",
    memory_mb = 3072,
    compute_intensity = 60.0,
    task_type = :cpu_intensive,
    depends_on = ["preprocess"],
    deadline = nothing,
    priority = 0.7
))

# Stage 4: Model training (use GPU if available)
push!(tasks, Task(
    "train_model",
    memory_mb = has_gpu ? 8192 : 6144,
    compute_intensity = 95.0,
    task_type = has_gpu ? :gpu_intensive : :cpu_intensive,
    depends_on = ["feature_extraction"],
    deadline = 180.0,  # 3-minute deadline
    priority = 1.0
))

# Stage 5: Validation
push!(tasks, Task(
    "validate",
    memory_mb = 2048,
    compute_intensity = 40.0,
    task_type = :cpu_intensive,
    depends_on = ["train_model"],
    deadline = nothing,
    priority = 0.8
))

# Stage 6: Save results
push!(tasks, Task(
    "save_results",
    memory_mb = 1024,
    compute_intensity = 20.0,
    task_type = :io_intensive,
    depends_on = ["validate"],
    deadline = nothing,
    priority = 0.4
))

println("Pipeline stages:")
for (i, task) in enumerate(tasks)
    deps_str = isempty(task.depends_on) ? "none" : join(task.depends_on, ", ")
    @printf("  %d. %s (depends on: %s)\n", i, task.id, deps_str)
    @printf("     Type: %s, Priority: %.1f\n", task.task_type, task.priority)
end

# ============================================================================
# Step 3: Task Scheduling
# ============================================================================

println("\n" * "="^80)
println("STEP 3: Task Scheduling with AutoScheduler")
println("="^80)
println()

# Determine optimization strategy based on system state
optimization = if metrics.total_cpu_usage > 70
    :energy  # System is busy, save energy
elseif has_gpu
    :performance  # Have GPU, maximize performance
else
    :balanced  # Balance performance and energy
end

println("Selected optimization strategy: $optimization")
@printf("  Based on: CPU usage %.1f%%, GPU available: %s\n",
        metrics.total_cpu_usage, has_gpu)
println()

println("Scheduling tasks...")
result = schedule(tasks, optimize_for=optimization, power_budget=150.0, verbose=true)

println("\n" * "-"^80)
println("Scheduling Results:")
println("-"^80)
@printf("Energy savings: %.1f%%\n", result.energy_savings_percent)
@printf("Time savings: %.1f%%\n", result.time_savings_percent)
@printf("Battery extension: %.1f minutes\n", result.battery_extension_minutes)
@printf("Cost savings: \$%.4f (at \$0.12/kWh)\n", result.cost_savings_dollars)
@printf("Baseline energy: %.2f J (%.4f Wh)\n", 
        result.baseline_energy, result.baseline_energy/3600)
@printf("Baseline time: %.2f seconds\n", result.baseline_time)

# Calculate optimized metrics
optimized_energy = result.baseline_energy * (1 - result.energy_savings_percent/100)
optimized_time = result.baseline_time * (1 - result.time_savings_percent/100)

@printf("Optimized energy: %.2f J (%.4f Wh)\n", 
        optimized_energy, optimized_energy/3600)
@printf("Optimized time: %.2f seconds\n", optimized_time)

# ============================================================================
# Step 4: Live Monitoring
# ============================================================================

println("\n" * "="^80)
println("STEP 4: Live System Monitoring")
println("="^80)
println()

println("Starting workload simulation and monitoring...")
println("(Running for 30 seconds)")
println()

# Start a background workload to simulate actual work
workload_task = @async begin
    for i in 1:30
        # Simulate computational work
        A = rand(300, 300)
        B = rand(300, 300)
        C = A * B
        sum(C)
        
        if i % 5 == 0
            println("  [Workload] Progress: $(i)/30 iterations")
        end
        
        sleep(0.5)
    end
    println("  [Workload] Completed")
end

sleep(2)  # Let workload start

# Run live scheduler
live_result = run_live_scheduler(
    duration = 30,
    interval = 5.0,
    min_cpu = 10.0,
    optimize_for = :energy
)

# Wait for workload to complete
wait(workload_task)

# ============================================================================
# Step 5: Results Analysis
# ============================================================================

println("\n" * "="^80)
println("STEP 5: Results Analysis")
println("="^80)
println()

println("Live Monitoring Summary:")
@printf("  Duration: %.1f seconds\n", live_result.duration)
@printf("  Total Energy: %.2f J (%.4f Wh)\n",
        live_result.total_energy_joules,
        live_result.total_energy_joules / 3600)
@printf("  Average Power: %.2f W\n", live_result.avg_power_watts)
@printf("  Processes Managed: %d\n", length(live_result.processes_managed))
@printf("  Actions Taken: %d\n", length(live_result.actions_taken))

if !isempty(live_result.energy_samples)
    powers = [s.total_watts for s in live_result.energy_samples]
    @printf("  Power Range: %.2f - %.2f W\n", minimum(powers), maximum(powers))
end

# Analyze actions
if !isempty(live_result.actions_taken)
    println("\nActions Breakdown:")
    action_counts = Dict{Symbol, Int}()
    for action in live_result.actions_taken
        action_counts[action.action_type] = get(action_counts, action.action_type, 0) + 1
    end
    
    for (action_type, count) in sort(collect(action_counts), by=x->x[2], rev=true)
        @printf("  %s: %d\n", action_type, count)
    end
end

# ============================================================================
# Step 6: Final Report
# ============================================================================

println("\n" * "="^80)
println("FINAL REPORT")
println("="^80)
println()

println("Workflow Summary:")
println("  Stages completed: $(length(tasks))")
println("  Optimization strategy: $optimization")
println()

println("Scheduling Benefits:")
energy_saved_wh = result.baseline_energy * result.energy_savings_percent / 100 / 3600
@printf("  Energy saved: %.4f Wh\n", energy_saved_wh)
@printf("  Time saved: %.2f seconds\n", 
        result.baseline_time * result.time_savings_percent / 100)
@printf("  Cost saved: \$%.4f\n", result.cost_savings_dollars)
println()

println("Live Monitoring Results:")
@printf("  Total energy consumed: %.4f Wh\n", 
        live_result.total_energy_joules / 3600)
@printf("  Average power draw: %.2f W\n", live_result.avg_power_watts)
@printf("  System interventions: %d\n", length(live_result.actions_taken))
println()

# Calculate theoretical annual savings
hours_per_day = 8  # Assume 8 hours of usage per day
days_per_year = 250  # Working days
annual_energy_kwh = energy_saved_wh * hours_per_day * days_per_year / 1000
annual_cost = annual_energy_kwh * 0.12  # At $0.12/kWh

println("Projected Annual Savings (8 hours/day, 250 days/year):")
@printf("  Energy: %.2f kWh\n", annual_energy_kwh)
@printf("  Cost: \$%.2f\n", annual_cost)
@printf("  CO₂ reduction: %.2f kg (at 0.4 kg CO₂/kWh)\n", 
        annual_energy_kwh * 0.4)
println()

# Recommendations
println("Recommendations:")
if result.energy_savings_percent > 20
    println("  ✓ Significant energy savings achieved")
    println("  → Continue using AutoScheduler for this workload")
else
    println("  • Moderate energy savings")
    println("  → Consider tuning parameters or workload")
end

if has_gpu && any(t -> t.task_type == :gpu_intensive, tasks)
    println("  ✓ GPU utilization optimized")
else
    println("  • Consider GPU acceleration for compute-intensive tasks")
end

if metrics.total_cpu_usage > 80
    println("  ⚠ High CPU utilization detected")
    println("  → Consider load balancing or scaling")
end

println("\n" * "="^80)
println("WORKFLOW COMPLETE")
println("="^80)
println()
println("AutoScheduler successfully:")
println("  1. ✓ Assessed system capabilities")
println("  2. ✓ Optimized task scheduling")
println("  3. ✓ Monitored execution in real-time")
println("  4. ✓ Achieved energy and time savings")
println("  5. ✓ Provided actionable insights")
println()
println("For production deployment:")
println("  • Use start_rest_server() for remote monitoring")
println("  • Use deploy_daemon() for background service")
println("  • Integrate with existing workflows via API")
println("  • Monitor long-term savings and trends")