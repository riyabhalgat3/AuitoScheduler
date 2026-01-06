# examples/04_dvfs_control.jl
using AutoScheduler
using AutoScheduler.DVFS
using Printf

println("\n" * "="^80)
println("EXAMPLE 4: DVFS (Dynamic Voltage Frequency Scaling) Control")
println("="^80)
println()

# ============================================================================
# Part 1: Detect DVFS Capability
# ============================================================================

println("Part 1: DVFS Capability Detection")
println("-"^80)

cap = detect_dvfs_capability(0)

println("DVFS Status:")
@printf("  Available: %s\n", cap.available ? "Yes ✓" : "No ✗")

if cap.available
    @printf("  Frequency Range: %.0f - %.0f MHz\n", cap.min_freq, cap.max_freq)
    @printf("  Number of Frequency Steps: %d\n", length(cap.available_freqs))
    @printf("  Per-Core Control: %s\n", cap.supports_per_core ? "Yes" : "No")
    
    if cap.current_governor !== nothing
        println("  Current Governor: $(cap.current_governor)")
    end
    
    println("\n  Available Frequencies:")
    for freq in cap.available_freqs
        @printf("    %.0f MHz\n", freq)
    end
else
    println("  DVFS is not available on this system")
    println("  Note: On some systems, DVFS requires root privileges")
end

# ============================================================================
# Part 2: Current Frequency
# ============================================================================

println("\n" * "="^80)
println("Part 2: Current CPU Frequency")
println("-"^80)

println("Per-Core Current Frequencies:")
for core_id in 0:min(7, Sys.CPU_THREADS-1)
    freq = get_current_frequency(core_id)
    @printf("  Core %d: %.0f MHz\n", core_id, freq)
end

# ============================================================================
# Part 3: Power Estimation
# ============================================================================

println("\n" * "="^80)
println("Part 3: Power Estimation at Different Frequencies")
println("-"^80)

freqs = get_available_frequencies(0)

println("Estimated Power Consumption:")
println()
@printf("%-15s %-12s %-12s %-12s\n", 
        "Frequency", "Idle Power", "50% Util", "100% Util")
println("-"^60)

for freq in freqs
    idle_power = estimate_power(freq, 1.0, 0.0)
    half_power = estimate_power(freq, 1.0, 0.5)
    full_power = estimate_power(freq, 1.0, 1.0)
    
    @printf("%-15.0f %-12.2f %-12.2f %-12.2f\n",
            freq, idle_power, half_power, full_power)
end

# ============================================================================
# Part 4: Energy Calculation
# ============================================================================

println("\n" * "="^80)
println("Part 4: Energy Consumption for Task")
println("-"^80)

# Simulate a task that takes 10 seconds at max frequency
base_time = 10.0
max_freq = maximum(freqs)

println("Task: 10 seconds at maximum frequency")
println()
@printf("%-15s %-15s %-15s %-15s\n",
        "Frequency", "Exec Time", "Energy (J)", "Savings")
println("-"^70)

for freq in freqs
    # Execution time scales inversely with frequency (approximation)
    exec_time = base_time * (max_freq / freq)
    energy = calculate_energy(exec_time, freq, 1.0)
    
    # Calculate savings compared to max frequency
    max_freq_energy = calculate_energy(base_time, max_freq, 1.0)
    savings_pct = (max_freq_energy - energy) / max_freq_energy * 100
    
    @printf("%-15.0f %-15.2f %-15.2f %-15.1f%%\n",
            freq, exec_time, energy, savings_pct)
end

# ============================================================================
# Part 5: Optimal Frequency Selection
# ============================================================================

println("\n" * "="^80)
println("Part 5: Optimal Frequency Selection")
println("-"^80)

# Get current system state
metrics = get_real_metrics()
cpu_usage = metrics.total_cpu_usage / 100.0
mem_bandwidth = 0.5  # Approximate

println("Current System State:")
@printf("  CPU Usage: %.1f%%\n", cpu_usage * 100)
@printf("  Memory Bandwidth: %.1f%%\n", mem_bandwidth * 100)
println()

# Test different power budgets
println("Optimal Frequency for Different Power Budgets:")
println()

for power_budget in [50.0, 80.0, 120.0, 200.0]
    optimal = get_optimal_frequency(cpu_usage, mem_bandwidth, power_budget, freqs)
    estimated_power = estimate_power(optimal, 1.0, cpu_usage)
    
    @printf("Power Budget: %6.1f W  →  Optimal Freq: %7.0f MHz (%.1f W)\n",
            power_budget, optimal, estimated_power)
end

# ============================================================================
# Part 6: Energy-Optimal Frequency
# ============================================================================

println("\n" * "="^80)
println("Part 6: Energy-Optimal Frequency with Deadline")
println("-"^80)

base_exec_time = 20.0  # seconds at max frequency

println("Finding energy-optimal frequency for different deadlines:")
println()
@printf("%-15s %-20s %-15s %-15s\n",
        "Deadline", "Optimal Freq", "Energy (J)", "Exec Time")
println("-"^70)

for deadline in [15.0, 25.0, 40.0, nothing]
    deadline_str = deadline === nothing ? "No deadline" : "$(deadline)s"
    
    optimal_freq = find_energy_optimal_frequency(
        freqs,
        base_exec_time,
        deadline,
        estimate_power
    )
    
    # Calculate actual execution time and energy
    exec_time = base_exec_time * (max_freq / optimal_freq)
    energy = calculate_energy(exec_time, optimal_freq, 1.0)
    
    @printf("%-15s %-20.0f %-15.2f %-15.2f\n",
            deadline_str, optimal_freq, energy, exec_time)
end

# ============================================================================
# Part 7: Workload-Based Frequency Selection
# ============================================================================

println("\n" * "="^80)
println("Part 7: Workload-Based Frequency Selection")
println("-"^80)

function recommend_frequency(workload_type::Symbol, freqs::Vector{Float64})
    max_freq = maximum(freqs)
    min_freq = minimum(freqs)
    mid_freq = freqs[length(freqs) ÷ 2]
    
    if workload_type == :cpu_bound
        return (max_freq, "CPU-bound: Use maximum frequency for performance")
    elseif workload_type == :memory_bound
        return (mid_freq, "Memory-bound: Moderate frequency (memory is bottleneck)")
    elseif workload_type == :io_bound
        return (min_freq, "I/O-bound: Minimum frequency (save energy)")
    elseif workload_type == :balanced
        return (mid_freq, "Balanced workload: Medium frequency")
    elseif workload_type == :bursty
        # Use governor instead of fixed frequency
        return (max_freq, "Bursty: Use ondemand/conservative governor")
    else
        return (mid_freq, "Unknown: Default to medium frequency")
    end
end

println("Frequency Recommendations by Workload Type:")
println()

for workload in [:cpu_bound, :memory_bound, :io_bound, :balanced, :bursty]
    freq, reason = recommend_frequency(workload, freqs)
    println("$workload:")
    @printf("  Recommended: %.0f MHz\n", freq)
    println("  Reason: $reason")
    println()
end

# ============================================================================
# Part 8: Frequency Governors
# ============================================================================

println("="^80)
println("Part 8: CPU Frequency Governors")
println("-"^80)

println("Available Governors:")
println()

governors = [
    (DVFS.PERFORMANCE, "Always run at maximum frequency"),
    (DVFS.POWERSAVE, "Always run at minimum frequency"),
    (DVFS.ONDEMAND, "Dynamically scale based on load (aggressive)"),
    (DVFS.CONSERVATIVE, "Dynamically scale based on load (gradual)"),
    (DVFS.SCHEDUTIL, "Scheduler-driven frequency selection"),
    (DVFS.USERSPACE, "Manual control via userspace")
]

for (gov, desc) in governors
    println("$(gov):")
    println("  $desc")
    println()
end

if cap.available && cap.current_governor !== nothing
    println("Current Governor: $(cap.current_governor)")
    println()
    println("Note: Changing governors requires root privileges")
    println("Example: sudo cpupower frequency-set -g powersave")
end

# ============================================================================
# Part 9: Power Model Creation
# ============================================================================

println("\n" * "="^80)
println("Part 9: Create Custom Power Model")
println("-"^80)

# Create sample measurements
measured_freqs = [800.0, 1600.0, 2400.0, 3200.0]
measured_powers = [15.0, 30.0, 55.0, 95.0]

println("Sample Measurements:")
for (freq, power) in zip(measured_freqs, measured_powers)
    @printf("  %.0f MHz: %.1f W\n", freq, power)
end

# Create power model
power_model = create_power_model(measured_freqs, measured_powers)

println("\nInterpolated Power Estimates:")
test_freqs = [1000.0, 1800.0, 2600.0, 3000.0]
for freq in test_freqs
    power = power_model(freq)
    @printf("  %.0f MHz: %.1f W\n", freq, power)
end

println("\n" * "="^80)
println("Example Complete!")
println("="^80)
println()
println("Summary:")
println("  • DVFS allows dynamic adjustment of CPU frequency")
println("  • Lower frequency = less power, slower execution")
println("  • Higher frequency = more power, faster execution")
println("  • Optimal frequency depends on workload and constraints")
println("  • Energy savings of 20-50% are possible with smart scaling")