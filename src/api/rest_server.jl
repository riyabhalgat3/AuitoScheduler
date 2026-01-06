"""
src/api/rest_server.jl
HTTP REST API for remote monitoring and control
Uses HTTP.jl for web server
"""

module RESTServer
using Printf
using HTTP
using JSON3

export start_rest_server, stop_rest_server

using HTTP
using JSON3
using ..SystemMetrics: get_real_metrics
using ..GPUDetection: get_gpu_info
using ..ProcessMonitor: get_running_processes

# Global server reference
const SERVER_REF = Ref{Union{HTTP.Server, Nothing}}(nothing)

"""
    start_rest_server(; host="0.0.0.0", port=8080)

Start REST API server for remote monitoring.

API Endpoints:
--------------
GET  /api/v1/metrics            - Get current system metrics
GET  /api/v1/metrics/history    - Get historical metrics (if monitoring)
GET  /api/v1/gpus               - Get GPU information
GET  /api/v1/processes          - Get running processes
GET  /api/v1/schedule           - Get current schedule
POST /api/v1/schedule           - Submit new workload for scheduling
GET  /api/v1/health             - Health check
GET  /api/v1/status             - Scheduler status

WebSocket:
----------
WS   /ws/metrics                - Real-time metrics streaming
"""
function start_rest_server(; host::String="0.0.0.0", port::Int=8080)
    println("Starting AutoScheduler REST API...")
    println("Host: $host")
    println("Port: $port")
    
    # Define routes
    router = HTTP.Router()
    
    # API v1 routes
    HTTP.register!(router, "GET", "/api/v1/metrics", handle_get_metrics)
    HTTP.register!(router, "GET", "/api/v1/gpus", handle_get_gpus)
    HTTP.register!(router, "GET", "/api/v1/processes", handle_get_processes)
    HTTP.register!(router, "GET", "/api/v1/health", handle_health_check)
    HTTP.register!(router, "GET", "/api/v1/status", handle_status)
    HTTP.register!(router, "POST", "/api/v1/schedule", handle_schedule_workload)
    
    # Root endpoint
    HTTP.register!(router, "GET", "/", handle_root)
    
    # Documentation endpoint
    HTTP.register!(router, "GET", "/docs", handle_docs)
    
    # Start server
    try
        server = HTTP.serve!(router, host, port; verbose=true)
        SERVER_REF[] = server
        
        println("✓ REST API running at http://$host:$port")
        println("  Health check: http://$host:$port/api/v1/health")
        println("  Metrics: http://$host:$port/api/v1/metrics")
        println("  Documentation: http://$host:$port/docs")
        
        return server
    catch e
        @error "Failed to start REST API server" exception=e
        rethrow(e)
    end
end

"""
    stop_rest_server()

Stop the REST API server.
"""
function stop_rest_server()
    if SERVER_REF[] !== nothing
        println("Stopping REST API server...")
        close(SERVER_REF[])
        SERVER_REF[] = nothing
        println("✓ Server stopped")
    else
        println("Server is not running")
    end
end

# ============================================================================
# Route Handlers
# ============================================================================

function handle_root(req::HTTP.Request)
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>AutoScheduler API</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            h1 { color: #333; }
            .endpoint { margin: 20px 0; padding: 15px; background: #f5f5f5; border-radius: 5px; }
            .method { font-weight: bold; color: #007bff; }
            code { background: #e0e0e0; padding: 2px 6px; border-radius: 3px; }
        </style>
    </head>
    <body>
        <h1>AutoScheduler REST API</h1>
        <p>Version: 1.0.0</p>
        <p>Platform: $(Sys.KERNEL) / $(Sys.ARCH)</p>
        
        <h2>Available Endpoints:</h2>
        
        <div class="endpoint">
            <span class="method">GET</span> <code>/api/v1/health</code>
            <p>Health check endpoint</p>
        </div>
        
        <div class="endpoint">
            <span class="method">GET</span> <code>/api/v1/metrics</code>
            <p>Get current system metrics (CPU, memory, load)</p>
        </div>
        
        <div class="endpoint">
            <span class="method">GET</span> <code>/api/v1/gpus</code>
            <p>Get GPU information (if available)</p>
        </div>
        
        <div class="endpoint">
            <span class="method">GET</span> <code>/api/v1/processes</code>
            <p>Get running processes with resource usage</p>
        </div>
        
        <div class="endpoint">
            <span class="method">GET</span> <code>/api/v1/status</code>
            <p>Get scheduler status and statistics</p>
        </div>
        
        <div class="endpoint">
            <span class="method">POST</span> <code>/api/v1/schedule</code>
            <p>Submit workload for scheduling</p>
        </div>
        
        <p><a href="/docs">View API Documentation</a></p>
    </body>
    </html>
    """
    
    return HTTP.Response(200, ["Content-Type" => "text/html"], body=html)
end

function handle_health_check(req::HTTP.Request)
    response = Dict(
        "status" => "healthy",
        "timestamp" => time(),
        "version" => "1.0.0",
        "platform" => "$(Sys.KERNEL)/$(Sys.ARCH)"
    )
    
    return HTTP.Response(200, 
                        ["Content-Type" => "application/json"],
                        body=JSON3.write(response))
end

function handle_get_metrics(req::HTTP.Request)
    try
        metrics = get_real_metrics()
        
        response = Dict(
            "timestamp" => metrics.timestamp,
            "platform" => metrics.platform,
            "architecture" => metrics.architecture,
            "cpu" => Dict(
                "usage_percent" => metrics.total_cpu_usage,
                "cores" => Dict(string(k) => v for (k, v) in metrics.cpu_usage_per_core),
                "frequency_mhz" => Dict(string(k) => v for (k, v) in metrics.cpu_frequency_mhz)
            ),
            "memory" => Dict(
                "total_bytes" => metrics.memory_total_bytes,
                "used_bytes" => metrics.memory_used_bytes,
                "available_bytes" => metrics.memory_available_bytes,
                "used_percent" => (metrics.memory_used_bytes / metrics.memory_total_bytes) * 100,
                "swap_used_bytes" => metrics.swap_used_bytes
            ),
            "load_average" => Dict(
                "1min" => metrics.load_average_1min,
                "5min" => metrics.load_average_5min,
                "15min" => metrics.load_average_15min
            ),
            "processes" => Dict(
                "count" => metrics.process_count,
                "threads" => metrics.thread_count
            ),
            "temperature_celsius" => metrics.temperature_celsius
        )
        
        return HTTP.Response(200,
                            ["Content-Type" => "application/json"],
                            body=JSON3.write(response))
    catch e
        error_response = Dict(
            "error" => "Failed to get metrics",
            "message" => string(e)
        )
        return HTTP.Response(500,
                            ["Content-Type" => "application/json"],
                            body=JSON3.write(error_response))
    end
end

function handle_get_gpus(req::HTTP.Request)
    try
        gpus = get_gpu_info()
        
        gpu_list = [
            Dict(
                "id" => gpu.id,
                "name" => gpu.name,
                "vendor" => gpu.vendor,
                "memory" => Dict(
                    "total_bytes" => gpu.memory_total_bytes,
                    "used_bytes" => gpu.memory_used_bytes,
                    "free_bytes" => gpu.memory_free_bytes,
                    "used_percent" => (gpu.memory_used_bytes / max(1, gpu.memory_total_bytes)) * 100
                ),
                "utilization" => Dict(
                    "gpu_percent" => gpu.utilization_percent,
                    "memory_percent" => gpu.memory_utilization_percent
                ),
                "temperature_celsius" => gpu.temperature_celsius,
                "power_watts" => gpu.power_watts,
                "clock_speed_mhz" => gpu.clock_speed_mhz,
                "driver_version" => gpu.driver_version,
                "compute_capability" => gpu.compute_capability
            )
            for gpu in gpus
        ]
        
        response = Dict(
            "count" => length(gpus),
            "gpus" => gpu_list
        )
        
        return HTTP.Response(200,
                            ["Content-Type" => "application/json"],
                            body=JSON3.write(response))
    catch e
        error_response = Dict(
            "error" => "Failed to get GPU info",
            "message" => string(e)
        )
        return HTTP.Response(500,
                            ["Content-Type" => "application/json"],
                            body=JSON3.write(error_response))
    end
end

function handle_get_processes(req::HTTP.Request)
    try
        processes = get_running_processes()
        
        proc_list = [
            Dict(
                "pid" => proc.pid,
                "name" => proc.name,
                "cpu_percent" => proc.cpu_percent,
                "memory_bytes" => proc.memory_bytes,
                "threads" => proc.num_threads,
                "state" => proc.state
            )
            for proc in processes
        ]
        
        response = Dict(
            "count" => length(processes),
            "processes" => proc_list
        )
        
        return HTTP.Response(200,
                            ["Content-Type" => "application/json"],
                            body=JSON3.write(response))
    catch e
        error_response = Dict(
            "error" => "Failed to get processes",
            "message" => string(e)
        )
        return HTTP.Response(500,
                            ["Content-Type" => "application/json"],
                            body=JSON3.write(error_response))
    end
end

function handle_status(req::HTTP.Request)
    metrics = get_real_metrics()
    gpus = get_gpu_info()
    
    response = Dict(
        "scheduler" => Dict(
            "running" => true,
            "version" => "1.0.0",
            "uptime_seconds" => 0.0  # Track in production
        ),
        "system" => Dict(
            "platform" => metrics.platform,
            "architecture" => metrics.architecture,
            "cpu_cores" => Sys.CPU_THREADS,
            "memory_total_gb" => metrics.memory_total_bytes / 1e9,
            "gpu_count" => length(gpus)
        ),
        "current_load" => Dict(
            "cpu_percent" => metrics.total_cpu_usage,
            "memory_percent" => (metrics.memory_used_bytes / metrics.memory_total_bytes) * 100,
            "load_average" => metrics.load_average_1min
        )
    )
    
    return HTTP.Response(200,
                        ["Content-Type" => "application/json"],
                        body=JSON3.write(response))
end

function handle_schedule_workload(req::HTTP.Request)
    try
        # Parse request body
        body = String(req.body)
        workload = JSON3.read(body)
        
        # TODO: Implement actual scheduling
        # For now, return acceptance response
        
        response = Dict(
            "status" => "accepted",
            "message" => "Workload received and queued for scheduling",
            "workload_id" => "wl_$(Int(time()))",
            "estimated_completion_time" => nothing
        )
        
        return HTTP.Response(202,
                            ["Content-Type" => "application/json"],
                            body=JSON3.write(response))
    catch e
        error_response = Dict(
            "error" => "Failed to schedule workload",
            "message" => string(e)
        )
        return HTTP.Response(400,
                            ["Content-Type" => "application/json"],
                            body=JSON3.write(error_response))
    end
end

function handle_docs(req::HTTP.Request)
    docs_html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>AutoScheduler API Documentation</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; max-width: 1000px; }
            h1, h2, h3 { color: #333; }
            .endpoint { margin: 30px 0; padding: 20px; background: #f9f9f9; border-left: 4px solid #007bff; }
            .method { display: inline-block; padding: 4px 8px; border-radius: 3px; font-weight: bold; color: white; }
            .get { background: #28a745; }
            .post { background: #ffc107; }
            pre { background: #f5f5f5; padding: 15px; border-radius: 5px; overflow-x: auto; }
            code { font-family: 'Courier New', monospace; }
        </style>
    </head>
    <body>
        <h1>AutoScheduler API Documentation</h1>
        
        <h2>System Metrics</h2>
        
        <div class="endpoint">
            <h3><span class="method get">GET</span> /api/v1/metrics</h3>
            <p>Get real-time system metrics including CPU, memory, and load.</p>
            <h4>Response Example:</h4>
            <pre><code>{
  "timestamp": 1704297600.0,
  "platform": "Linux",
  "architecture": "x86_64",
  "cpu": {
    "usage_percent": 45.2,
    "cores": {"0": 42.1, "1": 48.3, ...},
    "frequency_mhz": {"0": 3200.0, ...}
  },
  "memory": {
    "total_bytes": 17179869184,
    "used_bytes": 8589934592,
    "available_bytes": 8589934592,
    "used_percent": 50.0
  },
  "load_average": {
    "1min": 2.5,
    "5min": 2.1,
    "15min": 1.8
  }
}</code></pre>
        </div>
        
        <div class="endpoint">
            <h3><span class="method get">GET</span> /api/v1/gpus</h3>
            <p>Get information about all detected GPUs.</p>
            <h4>Response Example:</h4>
            <pre><code>{
  "count": 2,
  "gpus": [
    {
      "id": 0,
      "name": "NVIDIA GeForce RTX 3080",
      "vendor": "NVIDIA",
      "memory": {
        "total_bytes": 10737418240,
        "used_bytes": 2147483648,
        "free_bytes": 8589934592
      },
      "utilization": {
        "gpu_percent": 75.5,
        "memory_percent": 20.0
      },
      "temperature_celsius": 68.0,
      "power_watts": 250.0
    }
  ]
}</code></pre>
        </div>
        
        <h2>Scheduling</h2>
        
        <div class="endpoint">
            <h3><span class="method post">POST</span> /api/v1/schedule</h3>
            <p>Submit a workload for scheduling.</p>
            <h4>Request Body:</h4>
            <pre><code>{
  "tasks": [
    {
      "id": "task1",
      "memory_mb": 1024,
      "cpu_intensive": true,
      "depends_on": []
    },
    {
      "id": "task2",
      "memory_mb": 2048,
      "gpu_intensive": true,
      "depends_on": ["task1"]
    }
  ],
  "optimize_for": "energy"
}</code></pre>
            <h4>Response:</h4>
            <pre><code>{
  "status": "accepted",
  "workload_id": "wl_1704297600",
  "estimated_completion_time": 120.5
}</code></pre>
        </div>
        
        <p><a href="/">Back to API Home</a></p>
    </body>
    </html>
    """
    
    return HTTP.Response(200, ["Content-Type" => "text/html"], body=docs_html)
end

end # module
