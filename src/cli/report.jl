# src/cli/report.jl  
module Report
using Printf
using Dates
export generate_system_report, generate_benchmark_report

"""Generate system report"""
function generate_system_report(output_file::String="system_report.md")
    using ..SystemMetrics, ..GPUDetection, ..ProcessMonitor
    
    open(output_file, "w") do io
        write(io, "# System Report\n\n")
        write(io, "**Generated:** $(now())\n\n")
        
        # System info
        metrics = get_real_metrics()
        write(io, "## System Information\n\n")
        write(io, "- Platform: $(metrics.platform)\n")
        write(io, "- Architecture: $(metrics.architecture)\n")
        write(io, "- CPU Cores: $(Sys.CPU_THREADS)\n")
        write(io, "- Memory: $(round(metrics.memory_total_bytes/1e9, digits=2)) GB\n\n")
        
        # CPU
        write(io, "## CPU Status\n\n")
        write(io, @sprintf("- Usage: %.1f%%\n", metrics.total_cpu_usage))
        write(io, @sprintf("- Load Average: %.2f\n", metrics.load_average_1min))
        
        # GPU
        gpus = get_gpu_info()
        if !isempty(gpus)
            write(io, "\n## GPU Information\n\n")
            for gpu in gpus
                write(io, "### GPU $(gpu.id): $(gpu.name)\n\n")
                write(io, "- Vendor: $(gpu.vendor)\n")
                write(io, @sprintf("- Memory: %.2f GB\n", gpu.memory_total_bytes/1e9))
                write(io, @sprintf("- Utilization: %.1f%%\n\n", gpu.utilization_percent))
            end
        end
        
        # Top processes
        procs = get_running_processes(5.0)
        write(io, "\n## Top Processes\n\n")
        write(io, "| PID | Name | CPU% | Memory |\n")
        write(io, "|-----|------|------|--------|\n")
        for proc in procs[1:min(10, end)]
            write(io, @sprintf("| %d | %s | %.1f%% | %.1f MB |\n",
                    proc.pid, proc.name, proc.cpu_percent, proc.memory_bytes/1e6))
        end
    end
    
    println("Report saved: $output_file")
end

"""Generate benchmark report"""
function generate_benchmark_report(results_dir::String, output_file::String="benchmark_report.md")
    using ..BenchmarkFramework
    # Load and generate report
    println("Generating benchmark report from: $results_dir")
    println("Report: $output_file")
end
end