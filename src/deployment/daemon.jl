"""
src/deployment/daemon.jl
Daemon manager for AutoScheduler background service
PRODUCTION VERSION (fixed include semantics)
"""

module DaemonManager

using Printf
using Dates

# Anchor all includes to THIS file
const _ROOT = @__DIR__

export deploy_daemon, stop_daemon, daemon_status
export DaemonConfig
export install_service, uninstall_service

using ..RESTServer: start_rest_server, stop_rest_server
using ..WebSocketStream: start_websocket_server, stop_websocket_server
using ..SystemMetrics: get_real_metrics, monitor_system

# ============================================================================
# Global daemon state
# ============================================================================

const DAEMON_STATE = Dict{String, Any}(
    "running" => false,
    "started_at" => nothing,
    "pid" => nothing,
    "config" => nothing
)

# ============================================================================
# Configuration
# ============================================================================

struct DaemonConfig
    rest_port::Int
    ws_port::Int
    log_file::String
    pid_file::String
    monitor_interval::Float64
    auto_optimize::Bool

    function DaemonConfig(;
        rest_port::Int=8080,
        ws_port::Int=8081,
        log_file::String="/var/log/autoscheduler.log",
        pid_file::String="/var/run/autoscheduler.pid",
        monitor_interval::Float64=1.0,
        auto_optimize::Bool=false
    )
        new(rest_port, ws_port, log_file, pid_file, monitor_interval, auto_optimize)
    end
end

# ============================================================================
# Daemon lifecycle
# ============================================================================

function deploy_daemon(config::DaemonConfig=DaemonConfig())
    if DAEMON_STATE["running"]
        @warn "Daemon already running"
        return false
    end

    println("Deploying AutoScheduler daemon...")

    try
        write(config.pid_file, string(getpid()))
    catch e
        @warn "PID file write failed" exception=e
    end

    try
        start_rest_server(host="0.0.0.0", port=config.rest_port)
        start_websocket_server(host="0.0.0.0", port=config.ws_port)
    catch e
        @error "Failed to start services" exception=e
        cleanup_daemon(config)
        return false
    end

    DAEMON_STATE["running"] = true
    DAEMON_STATE["started_at"] = time()
    DAEMON_STATE["pid"] = getpid()
    DAEMON_STATE["config"] = config

    if config.monitor_interval > 0
        @async monitoring_loop(config)
    end

    try
        while DAEMON_STATE["running"]
            sleep(1)
        end
    catch e
        if !(e isa InterruptException)
            @error "Daemon runtime error" exception=e
        end
    finally
        stop_daemon()
    end

    return true
end

function stop_daemon()
    if !DAEMON_STATE["running"]
        return
    end

    config = DAEMON_STATE["config"]

    try stop_rest_server() catch end
    try stop_websocket_server() catch end

    cleanup_daemon(config)

    DAEMON_STATE["running"] = false
    DAEMON_STATE["started_at"] = nothing
    DAEMON_STATE["pid"] = nothing
end

function daemon_status()
    if !DAEMON_STATE["running"]
        return Dict("running" => false)
    end

    uptime = time() - DAEMON_STATE["started_at"]

    return Dict(
        "running" => true,
        "pid" => DAEMON_STATE["pid"],
        "uptime_seconds" => uptime,
        "uptime_formatted" => format_duration(uptime)
    )
end

# ============================================================================
# Internal helpers
# ============================================================================

function cleanup_daemon(config::DaemonConfig)
    if isfile(config.pid_file)
        try rm(config.pid_file) catch end
    end
end

function monitoring_loop(config::DaemonConfig)
    while DAEMON_STATE["running"]
        try
            metrics = get_real_metrics()
            sleep(config.monitor_interval)
        catch
            sleep(config.monitor_interval)
        end
    end
end

function format_duration(seconds::Float64)
    days = floor(Int, seconds / 86400)
    seconds -= days * 86400
    hours = floor(Int, seconds / 3600)
    seconds -= hours * 3600
    minutes = floor(Int, seconds / 60)
    seconds -= minutes * 60
    return days > 0 ? "$(days)d $(hours)h $(minutes)m" :
           hours > 0 ? "$(hours)h $(minutes)m" :
           minutes > 0 ? "$(minutes)m $(Int(seconds))s" :
           "$(Int(seconds))s"
end

# ============================================================================
# Service installation (FIXED includes)
# ============================================================================

function install_service()
    if Sys.islinux()
        include(joinpath(_ROOT, "systemd.jl"))
        SystemdService.install_systemd_service()
    elseif Sys.isapple()
        include(joinpath(_ROOT, "launchd.jl"))
        LaunchdService.install_launchd_service()
    elseif Sys.iswindows()
        include(joinpath(_ROOT, "windows_service.jl"))
        WindowsService.install_windows_service()
    else
        error("Service installation not supported on $(Sys.KERNEL)")
    end
end

function uninstall_service()
    if Sys.islinux()
        include(joinpath(_ROOT, "systemd.jl"))
        SystemdService.uninstall_systemd_service()
    elseif Sys.isapple()
        include(joinpath(_ROOT, "launchd.jl"))
        LaunchdService.uninstall_launchd_service()
    elseif Sys.iswindows()
        include(joinpath(_ROOT, "windows_service.jl"))
        WindowsService.uninstall_windows_service()
    else
        error("Service uninstallation not supported on $(Sys.KERNEL)")
    end
end

end # module DaemonManager
