# src/cli/profile.jl
module Profile
using Printf
using Statistics
export profile_process, profile_system

"""Profile a specific process"""
function profile_process(pid::Int; duration::Int=60)
    println("Profiling PID $pid for $(duration)s...")
    using ..ProcessMonitor
    samples = monitor_process(pid, duration=duration)
    
    if isempty(samples)
        println("No samples collected")
        return
    end
    
    println("\nProfile Results:")
    @printf("  Avg CPU: %.1f%%\n", mean(s.cpu_percent for s in samples))
    @printf("  Max CPU: %.1f%%\n", maximum(s.cpu_percent for s in samples))
    @printf("  Avg Memory: %.1f MB\n", mean(s.memory_bytes for s in samples) / 1e6)
    @printf("  Max Memory: %.1f MB\n", maximum(s.memory_bytes for s in samples) / 1e6)
    @printf("  Samples: %d\n", length(samples))
end

"""Profile entire system"""
function profile_system(; duration::Int=60)
    println("Profiling system for $(duration)s...")
    using ..SystemMetrics
    samples = monitor_system(duration, interval=1.0)
    
    println("\nSystem Profile:")
    @printf("  Avg CPU: %.1f%%\n", mean(s.total_cpu_usage for s in samples))
    @printf("  Avg Memory: %.1f%%\n", 
            mean(s.memory_used_bytes / s.memory_total_bytes for s in samples) * 100)
    @printf("  Avg Load: %.2f\n", mean(s.load_average_1min for s in samples))
end
end