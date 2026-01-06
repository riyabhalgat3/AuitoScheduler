"""
src/api/client_sdk.jl
Client SDK for interacting with AutoScheduler API
COMPLETE PRODUCTION VERSION - 380 lines
"""

module ClientSDK
using Printf
using HTTP
using JSON3

export AutoSchedulerClient
export get_metrics, get_gpus, get_processes, get_status
export submit_workload, get_workload_status, cancel_workload
export stream_metrics, stream_gpus, stream_processes

using HTTP
using JSON3

"""
    AutoSchedulerClient

Client for interacting with AutoScheduler REST and WebSocket APIs.

# Fields
- `base_url::String` - REST API base URL
- `ws_url::String` - WebSocket base URL
- `timeout::Float64` - Request timeout in seconds
- `headers::Dict` - Additional HTTP headers
"""
mutable struct AutoSchedulerClient
    base_url::String
    ws_url::String
    timeout::Float64
    headers::Dict{String, String}
    
    function AutoSchedulerClient(;
        host::String="localhost",
        port::Int=8080,
        ws_port::Int=8081,
        timeout::Float64=30.0,
        headers::Dict{String, String}=Dict{String, String}()
    )
        base_url = "http://$host:$port"
        ws_url = "ws://$host:$ws_port"
        
        default_headers = Dict(
            "Content-Type" => "application/json",
            "Accept" => "application/json",
            "User-Agent" => "AutoScheduler-Client/1.0.0"
        )
        
        merged_headers = merge(default_headers, headers)
        
        new(base_url, ws_url, timeout, merged_headers)
    end
end

# ============================================================================
# REST API Methods
# ============================================================================

"""
    get_metrics(client::AutoSchedulerClient)

Get current system metrics from the scheduler.

# Returns
- `Dict` containing CPU, memory, and load metrics
"""
function get_metrics(client::AutoSchedulerClient)
    url = "$(client.base_url)/api/v1/metrics"
    
    try
        response = HTTP.get(
            url,
            headers=collect(pairs(client.headers)),
            readtimeout=client.timeout
        )
        
        if response.status == 200
            return JSON3.read(String(response.body))
        else
            error("Request failed with status $(response.status)")
        end
    catch e
        @error "Failed to get metrics" url=url exception=e
        rethrow(e)
    end
end

"""
    get_gpus(client::AutoSchedulerClient)

Get information about detected GPUs.

# Returns
- `Dict` containing GPU information
"""
function get_gpus(client::AutoSchedulerClient)
    url = "$(client.base_url)/api/v1/gpus"
    
    try
        response = HTTP.get(
            url,
            headers=collect(pairs(client.headers)),
            readtimeout=client.timeout
        )
        
        if response.status == 200
            return JSON3.read(String(response.body))
        else
            error("Request failed with status $(response.status)")
        end
    catch e
        @error "Failed to get GPU info" url=url exception=e
        rethrow(e)
    end
end

"""
    get_processes(client::AutoSchedulerClient)

Get running processes with resource usage.

# Returns
- `Dict` containing process information
"""
function get_processes(client::AutoSchedulerClient)
    url = "$(client.base_url)/api/v1/processes"
    
    try
        response = HTTP.get(
            url,
            headers=collect(pairs(client.headers)),
            readtimeout=client.timeout
        )
        
        if response.status == 200
            return JSON3.read(String(response.body))
        else
            error("Request failed with status $(response.status)")
        end
    catch e
        @error "Failed to get processes" url=url exception=e
        rethrow(e)
    end
end

"""
    get_status(client::AutoSchedulerClient)

Get scheduler status and statistics.

# Returns
- `Dict` containing scheduler status
"""
function get_status(client::AutoSchedulerClient)
    url = "$(client.base_url)/api/v1/status"
    
    try
        response = HTTP.get(
            url,
            headers=collect(pairs(client.headers)),
            readtimeout=client.timeout
        )
        
        if response.status == 200
            return JSON3.read(String(response.body))
        else
            error("Request failed with status $(response.status)")
        end
    catch e
        @error "Failed to get status" url=url exception=e
        rethrow(e)
    end
end

"""
    health_check(client::AutoSchedulerClient)

Check if the scheduler is healthy and responding.

# Returns
- `Bool` - true if healthy, false otherwise
"""
function health_check(client::AutoSchedulerClient)
    url = "$(client.base_url)/api/v1/health"
    
    try
        response = HTTP.get(
            url,
            headers=collect(pairs(client.headers)),
            readtimeout=client.timeout
        )
        
        if response.status == 200
            data = JSON3.read(String(response.body))
            return get(data, "status", "") == "healthy"
        else
            return false
        end
    catch e
        @warn "Health check failed" exception=e
        return false
    end
end

"""
    submit_workload(client::AutoSchedulerClient, workload::Dict)

Submit a workload for scheduling.

# Arguments
- `workload::Dict` - Workload specification containing tasks and configuration

# Example
```julia
workload = Dict(
    "tasks" => [
        Dict("id" => "task1", "memory_mb" => 1024, "cpu_intensive" => true),
        Dict("id" => "task2", "memory_mb" => 2048, "gpu_intensive" => true, 
             "depends_on" => ["task1"])
    ],
    "optimize_for" => "energy"
)

result = submit_workload(client, workload)
```

# Returns
- `Dict` containing workload_id and status
"""
function submit_workload(client::AutoSchedulerClient, workload::Dict)
    url = "$(client.base_url)/api/v1/schedule"
    
    try
        response = HTTP.post(
            url,
            headers=collect(pairs(client.headers)),
            body=JSON3.write(workload),
            readtimeout=client.timeout
        )
        
        if response.status in [200, 202]
            return JSON3.read(String(response.body))
        else
            error("Request failed with status $(response.status)")
        end
    catch e
        @error "Failed to submit workload" url=url exception=e
        rethrow(e)
    end
end

"""
    get_workload_status(client::AutoSchedulerClient, workload_id::String)

Get the status of a submitted workload.

# Returns
- `Dict` containing workload status
"""
function get_workload_status(client::AutoSchedulerClient, workload_id::String)
    url = "$(client.base_url)/api/v1/workload/$workload_id"
    
    try
        response = HTTP.get(
            url,
            headers=collect(pairs(client.headers)),
            readtimeout=client.timeout
        )
        
        if response.status == 200
            return JSON3.read(String(response.body))
        else
            error("Request failed with status $(response.status)")
        end
    catch e
        @error "Failed to get workload status" workload_id=workload_id exception=e
        rethrow(e)
    end
end

"""
    cancel_workload(client::AutoSchedulerClient, workload_id::String)

Cancel a submitted workload.

# Returns
- `Bool` - true if cancelled successfully
"""
function cancel_workload(client::AutoSchedulerClient, workload_id::String)
    url = "$(client.base_url)/api/v1/workload/$workload_id"
    
    try
        response = HTTP.delete(
            url,
            headers=collect(pairs(client.headers)),
            readtimeout=client.timeout
        )
        
        return response.status in [200, 204]
    catch e
        @error "Failed to cancel workload" workload_id=workload_id exception=e
        return false
    end
end

# ============================================================================
# WebSocket Streaming Methods
# ============================================================================

"""
    stream_metrics(client::AutoSchedulerClient, callback::Function)

Stream real-time system metrics via WebSocket.

# Arguments
- `callback::Function` - Function to call with each metric update
  Signature: `callback(metrics::Dict) -> nothing`

# Example
```julia
stream_metrics(client) do metrics
    println("CPU: \$(metrics["data"]["cpu"]["usage_percent"])%")
end
```
"""
function stream_metrics(client::AutoSchedulerClient, callback::Function)
    url = "$(client.ws_url)/ws/metrics"
    
    try
        HTTP.WebSockets.open(url) do ws
            while isopen(ws)
                msg = HTTP.WebSockets.receive(ws)
                data = JSON3.read(String(msg))
                
                try
                    callback(data)
                catch e
                    @error "Error in callback" exception=e
                end
            end
        end
    catch e
        @error "WebSocket connection failed" url=url exception=e
        rethrow(e)
    end
end

"""
    stream_gpus(client::AutoSchedulerClient, callback::Function)

Stream real-time GPU metrics via WebSocket.
"""
function stream_gpus(client::AutoSchedulerClient, callback::Function)
    url = "$(client.ws_url)/ws/gpus"
    
    try
        HTTP.WebSockets.open(url) do ws
            while isopen(ws)
                msg = HTTP.WebSockets.receive(ws)
                data = JSON3.read(String(msg))
                
                try
                    callback(data)
                catch e
                    @error "Error in callback" exception=e
                end
            end
        end
    catch e
        @error "WebSocket connection failed" url=url exception=e
        rethrow(e)
    end
end

"""
    stream_processes(client::AutoSchedulerClient, callback::Function)

Stream real-time process updates via WebSocket.
"""
function stream_processes(client::AutoSchedulerClient, callback::Function)
    url = "$(client.ws_url)/ws/processes"
    
    try
        HTTP.WebSockets.open(url) do ws
            while isopen(ws)
                msg = HTTP.WebSockets.receive(ws)
                data = JSON3.read(String(msg))
                
                try
                    callback(data)
                catch e
                    @error "Error in callback" exception=e
                end
            end
        end
    catch e
        @error "WebSocket connection failed" url=url exception=e
        rethrow(e)
    end
end

"""
    stream_events(client::AutoSchedulerClient, callback::Function)

Stream scheduler events via WebSocket.
"""
function stream_events(client::AutoSchedulerClient, callback::Function)
    url = "$(client.ws_url)/ws/events"
    
    try
        HTTP.WebSockets.open(url) do ws
            while isopen(ws)
                msg = HTTP.WebSockets.receive(ws)
                data = JSON3.read(String(msg))
                
                try
                    callback(data)
                catch e
                    @error "Error in callback" exception=e
                end
            end
        end
    catch e
        @error "WebSocket connection failed" url=url exception=e
        rethrow(e)
    end
end

# ============================================================================
# Convenience Functions
# ============================================================================

"""
    print_metrics(client::AutoSchedulerClient)

Print current metrics in a formatted way.
"""
function print_metrics(client::AutoSchedulerClient)
    metrics = get_metrics(client)
    
    println("=" ^ 70)
    println("SYSTEM METRICS")
    println("=" ^ 70)
    
    cpu_data = metrics["data"]["cpu"]
    mem_data = metrics["data"]["memory"]
    load_data = metrics["data"]["load_average"]
    
    println("\nCPU:")
    println("  Usage: $(round(cpu_data["usage_percent"], digits=1))%")
    
    println("\nMemory:")
    println("  Total: $(round(mem_data["total_bytes"] / 1e9, digits=2))GB")
    println("  Used: $(round(mem_data["used_bytes"] / 1e9, digits=2))GB")
    println("  Available: $(round(mem_data["available_bytes"] / 1e9, digits=2))GB")
    println("  Usage: $(round(mem_data["used_percent"], digits=1))%")
    
    println("\nLoad Average:")
    println("  1 min: $(round(load_data["1min"], digits=2))")
    println("  5 min: $(round(load_data["5min"], digits=2))")
    println("  15 min: $(round(load_data["15min"], digits=2))")
    
    println("=" ^ 70)
end

"""
    print_gpus(client::AutoSchedulerClient)

Print GPU information in a formatted way.
"""
function print_gpus(client::AutoSchedulerClient)
    gpu_data = get_gpus(client)
    
    println("=" ^ 70)
    println("GPU INFORMATION")
    println("=" ^ 70)
    
    if gpu_data["count"] == 0
        println("\nNo GPUs detected")
    else
        for gpu in gpu_data["gpus"]
            println("\nGPU $(gpu["id"]): $(gpu["name"])")
            println("  Vendor: $(gpu["vendor"])")
            println("  Memory: $(round(gpu["memory"]["total_bytes"] / 1e9, digits=2))GB")
            println("  GPU Utilization: $(round(gpu["utilization"]["gpu_percent"], digits=1))%")
            println("  Memory Utilization: $(round(gpu["utilization"]["memory_percent"], digits=1))%")
            
            if gpu["temperature_celsius"] !== nothing
                println("  Temperature: $(round(gpu["temperature_celsius"], digits=1))°C")
            end
            
            if gpu["power_watts"] !== nothing
                println("  Power: $(round(gpu["power_watts"], digits=1))W")
            end
        end
    end
    
    println("=" ^ 70)
end

"""
    monitor_dashboard(client::AutoSchedulerClient; duration=60)

Display a live monitoring dashboard for the specified duration.
"""
function monitor_dashboard(client::AutoSchedulerClient; duration::Int=60)
    println("Starting monitoring dashboard...")
    println("Duration: $(duration) seconds")
    println("Press Ctrl+C to stop")
    println()
    
    start_time = time()
    
    while (time() - start_time) < duration
        try
            metrics = get_metrics(client)
            
            # Clear screen (ANSI escape code)
            print("\033[2J\033[H")
            
            println("╔════════════════════════════════════════════╗")
            println("║   AutoScheduler Monitoring Dashboard      ║")
            println("╚════════════════════════════════════════════╝")
            println()
            
            cpu_data = metrics["data"]["cpu"]
            mem_data = metrics["data"]["memory"]
            
            println("CPU: $(round(cpu_data["usage_percent"], digits=1))%")
            println("Memory: $(round(mem_data["used_percent"], digits=1))%")
            println("Load: $(round(metrics["data"]["load_average"]["1min"], digits=2))")
            
            elapsed = Int(round(time() - start_time))
            remaining = duration - elapsed
            println("\nTime: $(elapsed)s / $(duration)s ($(remaining)s remaining)")
            
            sleep(1.0)
        catch e
            if e isa InterruptException
                println("\nMonitoring stopped by user")
                break
            end
            @error "Error in dashboard" exception=e
            sleep(1.0)
        end
    end
    
    println("\nMonitoring complete")
end

end # module ClientSDK
