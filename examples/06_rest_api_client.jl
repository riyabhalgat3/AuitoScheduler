# examples/06_rest_api_client.jl
using AutoScheduler
using AutoScheduler.ClientSDK
using Printf

println("\n" * "="^80)
println("EXAMPLE 6: REST API Client")
println("="^80)
println()

println("NOTE: This example requires the REST API server to be running.")
println("Start the server first with: start_rest_server(port=8080)")
println()

# ============================================================================
# Part 1: Start Server (for demo purposes)
# ============================================================================

println("Part 1: Starting REST API Server")
println("-"^80)

println("Starting server on port 8080...")
server_task = @async start_rest_server(port=8080)
sleep(3)  # Wait for server to start

println("✓ Server started")
println()

# ============================================================================
# Part 2: Create Client and Health Check
# ============================================================================

println("="^80)
println("Part 2: Client Setup and Health Check")
println("-"^80)

# Create client
client = AutoSchedulerClient(host="localhost", port=8080)

println("Created client:")
println("  Base URL: $(client.base_url)")
println("  WebSocket URL: $(client.ws_url)")
println("  Timeout: $(client.timeout)s")
println()

# Health check
println("Performing health check...")
if health_check(client)
    println("✓ Scheduler is healthy and responding")
else
    println("✗ Scheduler is not responding")
    println("Make sure the server is running!")
    exit(1)
end

# ============================================================================
# Part 3: Get System Metrics
# ============================================================================

println("\n" * "="^80)
println("Part 3: Fetching System Metrics")
println("-"^80)

try
    metrics = get_metrics(client)
    
    println("System Metrics:")
    println("  Timestamp: $(metrics["timestamp"])")
    println("  Platform: $(metrics["platform"])")
    println("  Architecture: $(metrics["architecture"])")
    println()
    
    cpu = metrics["data"]["cpu"]
    @printf("  CPU Usage: %.1f%%\n", cpu["usage_percent"])
    
    if haskey(cpu, "cores") && !isempty(cpu["cores"])
        println("  Per-Core Usage:")
        for (core, usage) in sort(collect(cpu["cores"]))
            @printf("    Core %s: %.1f%%\n", core, usage)
        end
    end
    
    mem = metrics["data"]["memory"]
    @printf("\n  Memory:\n")
    @printf("    Total: %.2f GB\n", mem["total_bytes"] / 1e9)
    @printf("    Used: %.2f GB\n", mem["used_bytes"] / 1e9)
    @printf("    Available: %.2f GB\n", mem["available_bytes"] / 1e9)
    @printf("    Usage: %.1f%%\n", mem["used_percent"])
    
    load = metrics["data"]["load_average"]
    @printf("\n  Load Average:\n")
    @printf("    1 min: %.2f\n", load["1min"])
    @printf("    5 min: %.2f\n", load["5min"])
    @printf("    15 min: %.2f\n", load["15min"])
    
catch e
    println("Error fetching metrics: $e")
end

# ============================================================================
# Part 4: Get GPU Information
# ============================================================================

println("\n" * "="^80)
println("Part 4: Fetching GPU Information")
println("-"^80)

try
    gpu_data = get_gpus(client)
    
    gpu_count = gpu_data["count"]
    println("GPUs detected: $gpu_count")
    
    if gpu_count > 0
        println()
        for gpu in gpu_data["gpus"]
            println("GPU $(gpu["id"]): $(gpu["name"])")
            println("  Vendor: $(gpu["vendor"])")
            
            mem = gpu["memory"]
            @printf("  Memory: %.2f GB / %.2f GB (%.1f%% used)\n",
                    mem["used_bytes"] / 1e9,
                    mem["total_bytes"] / 1e9,
                    mem["used_percent"])
            
            util = gpu["utilization"]
            @printf("  GPU Utilization: %.1f%%\n", util["gpu_percent"])
            @printf("  Memory Utilization: %.1f%%\n", util["memory_percent"])
            
            if gpu["temperature_celsius"] !== nothing
                @printf("  Temperature: %.1f°C\n", gpu["temperature_celsius"])
            end
            
            if gpu["power_watts"] !== nothing
                @printf("  Power: %.1f W\n", gpu["power_watts"])
            end
            
            println("  Driver: $(gpu["driver_version"])")
            println()
        end
    else
        println("No GPUs detected")
    end
    
catch e
    println("Error fetching GPU info: $e")
end

# ============================================================================
# Part 5: Get Running Processes
# ============================================================================

println("="^80)
println("Part 5: Fetching Running Processes")
println("-"^80)

try
    proc_data = get_processes(client)
    
    proc_count = proc_data["count"]
    println("Active processes: $proc_count")
    println()
    
    if proc_count > 0
        @printf("%-8s %-25s %8s %12s %8s\n",
                "PID", "Name", "CPU%", "Memory", "Threads")
        println("-"^70)
        
        for proc in proc_data["processes"][1:min(10, proc_count)]
            @printf("%-8d %-25s %7.1f%% %11.1f MB %8d\n",
                    proc["pid"],
                    proc["name"][1:min(end, 25)],
                    proc["cpu_percent"],
                    proc["memory_bytes"] / 1e6,
                    proc["threads"])
        end
    end
    
catch e
    println("Error fetching processes: $e")
end

# ============================================================================
# Part 6: Get Scheduler Status
# ============================================================================

println("\n" * "="^80)
println("Part 6: Scheduler Status")
println("-"^80)

try
    status = get_status(client)
    
    scheduler = status["scheduler"]
    println("Scheduler:")
    println("  Running: $(scheduler["running"])")
    println("  Version: $(scheduler["version"])")
    @printf("  Uptime: %.1f seconds\n", scheduler["uptime_seconds"])
    
    system = status["system"]
    println("\nSystem:")
    println("  Platform: $(system["platform"])")
    println("  Architecture: $(system["architecture"])")
    println("  CPU Cores: $(system["cpu_cores"])")
    @printf("  Memory: %.1f GB\n", system["memory_total_gb"])
    println("  GPU Count: $(system["gpu_count"])")
    
    load = status["current_load"]
    println("\nCurrent Load:")
    @printf("  CPU: %.1f%%\n", load["cpu_percent"])
    @printf("  Memory: %.1f%%\n", load["memory_percent"])
    @printf("  Load Average: %.2f\n", load["load_average"])
    
catch e
    println("Error fetching status: $e")
end

# ============================================================================
# Part 7: Submit Workload
# ============================================================================

println("\n" * "="^80)
println("Part 7: Submitting Workload")
println("-"^80)

try
    workload = Dict(
        "tasks" => [
            Dict(
                "id" => "task1",
                "memory_mb" => 1024,
                "cpu_intensive" => true,
                "depends_on" => []
            ),
            Dict(
                "id" => "task2",
                "memory_mb" => 2048,
                "gpu_intensive" => true,
                "depends_on" => ["task1"]
            )
        ],
        "optimize_for" => "energy"
    )
    
    println("Submitting workload:")
    println("  Tasks: $(length(workload["tasks"]))")
    println("  Optimization: $(workload["optimize_for"])")
    println()
    
    result = submit_workload(client, workload)
    
    println("Workload submitted:")
    println("  Status: $(result["status"])")
    println("  Workload ID: $(result["workload_id"])")
    println("  Message: $(result["message"])")
    
catch e
    println("Error submitting workload: $e")
end

# ============================================================================
# Part 8: Helper Functions
# ============================================================================

println("\n" * "="^80)
println("Part 8: Using Helper Functions")
println("-"^80)

try
    println("Formatted Metrics:")
    println()
    print_metrics(client)
    
catch e
    println("Error: $e")
end

try
    println("\nFormatted GPU Info:")
    println()
    print_gpus(client)
    
catch e
    println("Error: $e")
end

# ============================================================================
# Part 9: Periodic Monitoring
# ============================================================================

println("\n" * "="^80)
println("Part 9: Periodic Monitoring (10 seconds)")
println("-"^80)

println("Monitoring system every 2 seconds for 10 seconds...")
println()

start_time = time()
while (time() - start_time) < 10
    try
        metrics = get_metrics(client)
        cpu = metrics["data"]["cpu"]["usage_percent"]
        mem = metrics["data"]["memory"]["used_percent"]
        load = metrics["data"]["load_average"]["1min"]
        
        elapsed = Int(round(time() - start_time))
        @printf("[%2ds] CPU: %5.1f%%  Memory: %5.1f%%  Load: %5.2f\n",
                elapsed, cpu, mem, load)
        
        sleep(2)
    catch e
        println("Error: $e")
        break
    end
end

# ============================================================================
# Part 10: Cleanup
# ============================================================================

println("\n" * "="^80)
println("Part 10: Cleanup")
println("-"^80)

println("Stopping server...")
stop_rest_server()
sleep(1)

println("✓ Server stopped")

println("\n" * "="^80)
println("Example Complete!")
println("="^80)
println()
println("Summary:")
println("  • Created REST API client")
println("  • Fetched system metrics, GPU info, and processes")
println("  • Submitted workload for scheduling")
println("  • Monitored system in real-time")
println()
println("For production use:")
println("  1. Start server: start_rest_server(port=8080)")
println("  2. Keep it running in background")
println("  3. Connect clients from anywhere")
println("  4. Use for monitoring, scheduling, and control")