# examples/03_custom_policy.jl
using AutoScheduler
using Printf

println("\n" * "="^80)
println("EXAMPLE 3: Custom Scheduling Policy")
println("="^80)
println()

# ============================================================================
# Part 1: Custom Classification Function
# ============================================================================

println("Part 1: Custom Process Classification")
println("-"^80)

# Define custom classification function
function my_custom_classifier(proc::ProcessInfo)::Symbol
    # Custom rules for classification
    if occursin("python", lowercase(proc.name)) && proc.cpu_percent > 70
        return :ml_training
    elseif occursin("julia", lowercase(proc.name)) && proc.cpu_percent > 60
        return :scientific_computing
    elseif occursin("node", lowercase(proc.name)) || occursin("npm", lowercase(proc.name))
        return :web_development
    elseif occursin("docker", lowercase(proc.name)) || occursin("container", lowercase(proc.name))
        return :containerized
    elseif proc.memory_bytes > 4_000_000_000
        return :memory_intensive
    elseif proc.cpu_percent > 80
        return :cpu_bound
    elseif proc.cpu_percent < 5
        return :idle
    else
        return :normal
    end
end

# Get processes and classify
processes = get_running_processes(1.0)

println("Custom Classification Results:")
println()
@printf("%-8s %-25s %8s %12s %20s\n",
        "PID", "Name", "CPU%", "Memory", "Custom Class")
println("-"^80)

for proc in processes[1:min(10, length(processes))]
    custom_class = my_custom_classifier(proc)
    @printf("%-8d %-25s %7.1f%% %11.1f MB %20s\n",
            proc.pid,
            proc.name[1:min(end, 25)],
            proc.cpu_percent,
            proc.memory_bytes / 1e6,
            string(custom_class))
end

# ============================================================================
# Part 2: Custom Scheduling Actions
# ============================================================================

println("\n" * "="^80)
println("Part 2: Custom Scheduling Actions")
println("-"^80)

function my_custom_scheduling_action(proc::ProcessInfo, class::Symbol)::String
    if class == :ml_training
        return "Assign to GPU, increase priority"
    elseif class == :scientific_computing
        return "Allocate more CPU cores, NUMA-aware placement"
    elseif class == :web_development
        return "Balance across cores, moderate priority"
    elseif class == :containerized
        return "Isolate resources, cgroup limits"
    elseif class == :memory_intensive
        return "Reduce CPU frequency to save energy"
    elseif class == :cpu_bound
        return "Maximum CPU frequency, single core pinning"
    elseif class == :idle
        return "Minimum frequency, deprioritize"
    else
        return "Default scheduling policy"
    end
end

println("Recommended Actions:")
println()

for proc in processes[1:min(10, length(processes))]
    custom_class = my_custom_classifier(proc)
    action = my_custom_scheduling_action(proc, custom_class)
    
    println("$(proc.name) [$(custom_class)]")
    println("  → $action")
    println()
end

# ============================================================================
# Part 3: Custom Priority Assignment
# ============================================================================

println("="^80)
println("Part 3: Custom Priority Assignment")
println("-"^80)

function assign_custom_priority(proc::ProcessInfo)::Float64
    # Priority score from 0.0 (lowest) to 1.0 (highest)
    
    base_priority = 0.5
    
    # Adjust based on CPU usage
    if proc.cpu_percent > 80
        base_priority += 0.2
    elseif proc.cpu_percent < 10
        base_priority -= 0.2
    end
    
    # Adjust based on memory usage
    if proc.memory_bytes > 8_000_000_000
        base_priority += 0.1
    end
    
    # Adjust based on process name
    if occursin("system", lowercase(proc.name)) || occursin("kernel", lowercase(proc.name))
        base_priority += 0.3  # System processes are important
    elseif occursin("chrome", lowercase(proc.name)) || occursin("firefox", lowercase(proc.name))
        base_priority += 0.1  # Browser slightly higher priority
    end
    
    # Clamp to valid range
    return clamp(base_priority, 0.0, 1.0)
end

println("Custom Priority Scores:")
println()
@printf("%-8s %-25s %8s %12s %10s\n",
        "PID", "Name", "CPU%", "Memory", "Priority")
println("-"^80)

# Sort by custom priority
priority_list = [(proc, assign_custom_priority(proc)) for proc in processes]
sort!(priority_list, by=x->x[2], rev=true)

for (proc, priority) in priority_list[1:min(10, length(priority_list))]
    @printf("%-8d %-25s %7.1f%% %11.1f MB %10.2f\n",
            proc.pid,
            proc.name[1:min(end, 25)],
            proc.cpu_percent,
            proc.memory_bytes / 1e6,
            priority)
end

# ============================================================================
# Part 4: Custom Energy Policy
# ============================================================================

println("\n" * "="^80)
println("Part 4: Custom Energy-Aware Policy")
println("-"^80)

function custom_energy_policy(proc::ProcessInfo)::Tuple{Symbol, String}
    cpu = proc.cpu_percent
    mem = proc.memory_bytes / 1e9  # GB
    
    if cpu < 10 && mem < 1.0
        return (:powersave, "Low activity: minimize power consumption")
    elseif cpu < 30 && mem < 2.0
        return (:conservative, "Light load: gradual frequency scaling")
    elseif cpu > 80 || mem > 8.0
        return (:performance, "Heavy load: maximize performance")
    elseif cpu > 50 && cpu <= 80
        return (:ondemand, "Moderate load: dynamic scaling")
    else
        return (:balanced, "Standard load: balanced performance/energy")
    end
end

println("Energy Policy Recommendations:")
println()

for proc in processes[1:min(10, length(processes))]
    policy, reason = custom_energy_policy(proc)
    println("$(proc.name)")
    @printf("  CPU: %.1f%%, Memory: %.2f GB\n", proc.cpu_percent, proc.memory_bytes / 1e9)
    println("  Policy: $policy")
    println("  Reason: $reason")
    println()
end

# ============================================================================
# Part 5: Workload-Specific Optimization
# ============================================================================

println("="^80)
println("Part 5: Workload-Specific Optimization")
println("-"^80)

function optimize_for_workload(workload_type::Symbol)
    println("Optimizing for: $workload_type")
    println()
    
    if workload_type == :data_science
        println("  • Allocate more memory")
        println("  • Enable hyperthreading")
        println("  • Prefer CPU over GPU for small datasets")
        println("  • Use moderate frequency (balance speed/energy)")
        
    elseif workload_type == :web_server
        println("  • Distribute across all cores")
        println("  • Lower frequency acceptable (I/O bound)")
        println("  • Optimize for response time")
        println("  • Network bandwidth priority")
        
    elseif workload_type == :video_encoding
        println("  • Use all available cores")
        println("  • Maximum CPU frequency")
        println("  • Large memory buffer")
        println("  • Consider GPU acceleration")
        
    elseif workload_type == :machine_learning
        println("  • Prioritize GPU allocation")
        println("  • Large memory requirement")
        println("  • Batch processing optimization")
        println("  • Consider model parallelism")
        
    elseif workload_type == :batch_processing
        println("  • Lower priority acceptable")
        println("  • Energy-efficient frequency")
        println("  • Can tolerate latency")
        println("  • Optimize for throughput")
    end
    println()
end

# Demonstrate different workload optimizations
for workload in [:data_science, :web_server, :video_encoding, :machine_learning, :batch_processing]
    optimize_for_workload(workload)
end

# ============================================================================
# Part 6: Real-time Policy Adaptation
# ============================================================================

println("="^80)
println("Part 6: Real-time Policy Adaptation")
println("-"^80)

function adaptive_policy(system_load::Float64, time_of_day::Int)
    println("Adaptive Policy Decision:")
    @printf("  System Load: %.1f%%\n", system_load)
    println("  Time of Day: $(time_of_day):00")
    println()
    
    # During work hours (9-17), prioritize performance
    if 9 <= time_of_day <= 17
        if system_load > 70
            println("  Decision: PERFORMANCE mode")
            println("  Reason: Work hours + high load")
        else
            println("  Decision: BALANCED mode")
            println("  Reason: Work hours + moderate load")
        end
    # During off-hours, prioritize energy savings
    else
        if system_load < 30
            println("  Decision: POWERSAVE mode")
            println("  Reason: Off-hours + low load")
        else
            println("  Decision: CONSERVATIVE mode")
            println("  Reason: Off-hours + some activity")
        end
    end
    println()
end

# Simulate different scenarios
current_hour = hour(now())
system_metrics = get_real_metrics()

println("Current Scenario:")
adaptive_policy(system_metrics.total_cpu_usage, current_hour)

println("Simulated Scenarios:")
adaptive_policy(85.0, 14)  # High load during work hours
adaptive_policy(25.0, 2)   # Low load at night
adaptive_policy(60.0, 10)  # Moderate load during work hours

println("="^80)
println("Example Complete!")
println("="^80)