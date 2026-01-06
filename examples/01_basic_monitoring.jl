# examples/01_basic_monitoring.jl
using AutoScheduler
using Printf

println("\n" * "="^80)
println("EXAMPLE 1: Basic System Monitoring")
println("="^80)
println()

# ============================================================================
# Part 1: System Metrics
# ============================================================================

println("Part 1: System Metrics")
println("-"^80)

metrics = get_real_metrics()

@printf("Platform: %s (%s)\n", metrics.platform, metrics.architecture)
@printf("CPU Cores: %d\n", Sys.CPU_THREADS)
@printf("Total CPU Usage: %.1f%%\n", metrics.total_cpu_usage)
@printf("Memory: %.2f GB / %.2f GB (%.1f%% used)\n",
        metrics.memory_used_bytes / 1e9,
        metrics.memory_total_bytes / 1e9,
        100 * metrics.memory_used_bytes / metrics.memory_total_bytes)
@printf("Load Average (1/5/15 min): %.2f / %.2f / %.2f\n",
        metrics.load_average_1min,
        metrics.load_average_5min,
        metrics.load_average_15min)

if metrics.temperature_celsius !== nothing
    @printf("Temperature: %.1f°C\n", metrics.temperature_celsius)
end

println("\nPer-Core CPU Usage:")
for (core, usage) in sort(collect(metrics.cpu_usage_per_core))
    @printf("  Core %2d: %5.1f%%\n", core, usage)
end

if !isempty(metrics.cpu_frequency_mhz)
    println("\nCPU Frequencies:")
    for (core, freq) in sort(collect(metrics.cpu_frequency_mhz))
        @printf("  Core %2d: %7.1f MHz\n", core, freq)
    end
end

# ============================================================================
# Part 2: GPU Detection
# ============================================================================

println("\n" * "="^80)
println("Part 2: GPU Detection")
println("-"^80)

gpus = get_gpu_info()

if isempty(gpus)
    println("No GPUs detected")
else
    println("Found $(length(gpus)) GPU(s):")
    
    for gpu in gpus
        println("\nGPU $(gpu.id): $(gpu.name)")
        println("  Vendor: $(gpu.vendor)")
        @printf("  Memory: %.2f GB / %.2f GB (%.1f%% used)\n",
                gpu.memory_used_bytes / 1e9,
                gpu.memory_total_bytes / 1e9,
                100 * gpu.memory_used_bytes / max(1, gpu.memory_total_bytes))
        @printf("  GPU Utilization: %.1f%%\n", gpu.utilization_percent)
        @printf("  Memory Utilization: %.1f%%\n", gpu.memory_utilization_percent)
        
        if gpu.temperature_celsius !== nothing
            @printf("  Temperature: %.1f°C\n", gpu.temperature_celsius)
        end
        
        if gpu.power_watts !== nothing
            @printf("  Power: %.1f W\n", gpu.power_watts)
        end
        
        if gpu.clock_speed_mhz !== nothing
            @printf("  Clock Speed: %.1f MHz\n", gpu.clock_speed_mhz)
        end
        
        println("  Driver: $(gpu.driver_version)")
        println("  Compute Capability: $(gpu.compute_capability)")
    end
end

# ============================================================================
# Part 3: Process Monitoring
# ============================================================================

println("\n" * "="^80)
println("Part 3: Active Processes")
println("-"^80)

processes = get_running_processes(5.0)  # Processes using >5% CPU

println("Found $(length(processes)) processes using >5% CPU:")
println()

if !isempty(processes)
    @printf("%-8s %-25s %8s %12s %8s %12s\n",
            "PID", "Name", "CPU%", "Memory", "Threads", "Class")
    println("-"^80)
    
    for proc in processes[1:min(15, length(processes))]
        class = classify_process(proc)
        @printf("%-8d %-25s %7.1f%% %11.1f MB %8d %12s\n",
                proc.pid,
                proc.name[1:min(end, 25)],
                proc.cpu_percent,
                proc.memory_bytes / 1e6,
                proc.num_threads,
                string(class))
    end
else
    println("No active processes above threshold")
end

# ============================================================================
# Part 4: Continuous Monitoring
# ============================================================================

println("\n" * "="^80)
println("Part 4: Continuous Monitoring (10 seconds)")
println("-"^80)

println("Monitoring system for 10 seconds...")
samples = monitor_system(10, interval=1.0)

println("\nMonitoring Summary:")
@printf("  Samples collected: %d\n", length(samples))

if !isempty(samples)
    cpu_values = [s.total_cpu_usage for s in samples]
    mem_values = [s.memory_used_bytes / s.memory_total_bytes * 100 for s in samples]
    load_values = [s.load_average_1min for s in samples]
    
    @printf("  Average CPU: %.1f%%\n", mean(cpu_values))
    @printf("  Max CPU: %.1f%%\n", maximum(cpu_values))
    @printf("  Min CPU: %.1f%%\n", minimum(cpu_values))
    @printf("  Average Memory: %.1f%%\n", mean(mem_values))
    @printf("  Average Load: %.2f\n", mean(load_values))
end

# ============================================================================
# Part 5: Power Measurement
# ============================================================================

println("\n" * "="^80)
println("Part 5: Power Measurement")
println("-"^80)

try
    using ..PowerMeasurement
    
    power = get_power_consumption()
    
    @printf("Power Measurement Method: %s\n", power.method)
    @printf("Total Power: %.2f W\n", power.total_watts)
    
    if power.cpu_watts !== nothing
        @printf("CPU Power: %.2f W\n", power.cpu_watts)
    end
    
    if power.gpu_watts !== nothing
        @printf("GPU Power: %.2f W\n", power.gpu_watts)
    end
    
    if power.memory_watts !== nothing
        @printf("Memory Power: %.2f W\n", power.memory_watts)
    end
catch e
    println("Power measurement not available: $e")
end

println("\n" * "="^80)
println("Example Complete!")
println("="^80)