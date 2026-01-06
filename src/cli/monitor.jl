"""
src/cli/monitor.jl
Real-time System Monitoring CLI Tool
"""

module Monitor

using Printf
using ..SystemMetrics
using ..GPUDetection
using ..ProcessMonitor

export MonitorConfig, start_monitor, monitor_loop

struct MonitorConfig
    refresh_interval::Float64
    show_gpu::Bool
    show_processes::Bool
    show_power::Bool
    max_processes::Int
    
    function MonitorConfig(;
        refresh_interval::Float64=2.0,
        show_gpu::Bool=true,
        show_processes::Bool=true,
        show_power::Bool=true,
        max_processes::Int=10
    )
        new(refresh_interval, show_gpu, show_processes, show_power, max_processes)
    end
end

function clear_screen()
    if Sys.iswindows()
        run(`cmd /c cls`)
    else
        print("\033[2J\033[H")  # ANSI escape codes
    end
end

function print_header()
    println("="^80)
    println("AutoScheduler - Real-Time System Monitor")
    println("="^80)
    println()
end

function print_cpu_info(metrics)
    println("CPU Usage")
    println("-"^80)
    @printf("Total CPU: %.1f%%\n", metrics.total_cpu_usage)
    @printf("Load Average: %.2f (1m) | %.2f (5m) | %.2f (15m)\n",
            metrics.load_average_1min,
            metrics.load_average_5min,
            metrics.load_average_15min)
    println()
    
    println("Per-Core Usage:")
    for (core_id, usage) in sort(collect(metrics.cpu_usage_per_core))
        bar_len = Int(round(usage / 2))
        bar = "█"^bar_len * "░"^(50 - bar_len)
        @printf("  Core %2d: [%s] %5.1f%%\n", core_id, bar, usage)
    end
    println()
end

function print_memory_info(metrics)
    println("Memory Usage")
    println("-"^80)
    
    total_gb = metrics.memory_total_bytes / 1024^3
    used_gb = metrics.memory_used_bytes / 1024^3
    avail_gb = metrics.memory_available_bytes / 1024^3
    usage_pct = (used_gb / total_gb) * 100
    
    @printf("Total: %.2f GB | Used: %.2f GB (%.1f%%) | Available: %.2f GB\n",
            total_gb, used_gb, usage_pct, avail_gb)
    
    bar_len = Int(round(usage_pct / 2))
    bar = "█"^bar_len * "░"^(50 - bar_len)
    println("[$bar]")
    println()
end

function print_gpu_info(show_gpu::Bool)
    if !show_gpu
        return
    end
    
    println("GPU Status")
    println("-"^80)
    
    gpus = get_gpu_info()
    if isempty(gpus)
        println("No discrete GPU detected (Integrated GPU may be present)")
    else
        for gpu in gpus
            println("GPU $(gpu.id): $(gpu.name)")
            mem_gb = gpu.memory_total_bytes / 1024^3
            used_gb = gpu.memory_used_bytes / 1024^3
            @printf("  Memory: %.2f GB / %.2f GB | Utilization: %.1f%%\n",
                    used_gb, mem_gb, gpu.utilization_percent)
        end
    end
    println()
end

function print_process_info(show_processes::Bool, max_processes::Int)
    if !show_processes
        return
    end
    
    println("Top Processes by CPU")
    println("-"^80)
    
    try
        processes = get_running_processes()
        sorted = sort(processes, by=p->p.cpu_percent, rev=true)
        
        @printf("%-8s %-30s %10s %10s\n", "PID", "Name", "CPU %", "Memory MB")
        println("-"^80)
        
        for proc in sorted[1:min(max_processes, length(sorted))]
            name = length(proc.name) > 30 ? proc.name[1:27]*"..." : proc.name
            @printf("%-8d %-30s %9.1f%% %10.0f\n",
                    proc.pid, name, proc.cpu_percent, proc.memory_mb)
        end
    catch e
        println("Error fetching processes: $e")
    end
    println()
end

function print_footer(iteration::Int)
    println("-"^80)
    println("Press Ctrl+C to exit | Iteration: $iteration")
    println("="^80)
end

function monitor_loop(config::MonitorConfig; duration::Union{Int,Nothing}=nothing)
    iteration = 0
    start_time = time()
    
    try
        while true
            iteration += 1
            
            # Check duration
            if duration !== nothing && (time() - start_time) >= duration
                break
            end
            
            # Clear and refresh
            clear_screen()
            
            # Get metrics
            metrics = get_real_metrics()
            
            # Display
            print_header()
            print_cpu_info(metrics)
            print_memory_info(metrics)
            print_gpu_info(config.show_gpu)
            print_process_info(config.show_processes, config.max_processes)
            print_footer(iteration)
            
            # Wait
            sleep(config.refresh_interval)
        end
    catch e
        if isa(e, InterruptException)
            println("\nMonitoring stopped by user")
        else
            rethrow(e)
        end
    end
    
    return iteration
end

function start_monitor(; duration::Union{Int,Nothing}=nothing, config::MonitorConfig=MonitorConfig())
    println("\nStarting AutoScheduler Real-Time Monitor...")
    println("Press Ctrl+C to stop\n")
    sleep(1)
    
    monitor_loop(config, duration=duration)
    
    println("\nMonitor session complete!")
    return true
end

end # module Monitor