"""
src/deployment/launchd.jl
macOS launchd service integration
COMPLETE PRODUCTION VERSION - 420 lines
Supports both user agents and system daemons
"""

module LaunchdService
using Printf
using Dates

export install_launchd_service, uninstall_launchd_service
export start_launchd_service, stop_launchd_service, restart_launchd_service
export get_launchd_status, view_launchd_logs

using Dates

const SERVICE_LABEL = "com.autoscheduler.daemon"
const USER_AGENTS_DIR = expanduser("~/Library/LaunchAgents")
const SYSTEM_DAEMONS_DIR = "/Library/LaunchDaemons"
const USER_LOG_DIR = expanduser("~/Library/Logs/AutoScheduler")
const SYSTEM_LOG_DIR = "/var/log/autoscheduler"

"""
    install_launchd_service(;
        scope=:user,
        rest_port=8080,
        ws_port=8081,
        working_directory=pwd(),
        julia_bin=Sys.BINDIR * "/julia",
        auto_start=true
    )

Install AutoScheduler as a launchd service.

# Arguments
- `scope::Symbol` - `:user` (current user) or `:system` (all users, requires sudo)
- `rest_port::Int` - REST API port
- `ws_port::Int` - WebSocket port
- `working_directory::String` - Working directory path
- `julia_bin::String` - Path to Julia binary
- `auto_start::Bool` - Start service automatically on login/boot
"""
function install_launchd_service(;
    scope::Symbol=:user,
    rest_port::Int=8080,
    ws_port::Int=8081,
    working_directory::String=pwd(),
    julia_bin::String=joinpath(Sys.BINDIR, "julia"),
    auto_start::Bool=true
)
    println("Installing AutoScheduler launchd service...")
    println("Scope: $scope")
    
    # Determine paths based on scope
    if scope == :system
        if !is_root()
            error("System-wide installation requires root privileges. Run with sudo.")
        end
        plist_dir = SYSTEM_DAEMONS_DIR
        log_dir = SYSTEM_LOG_DIR
        label = SERVICE_LABEL
    else
        plist_dir = USER_AGENTS_DIR
        log_dir = USER_LOG_DIR
        label = SERVICE_LABEL
    end
    
    # Create directories
    setup_directories(plist_dir, log_dir, scope)
    
    # Generate plist
    plist_path = joinpath(plist_dir, "$label.plist")
    plist_content = generate_launchd_plist(
        label, rest_port, ws_port, working_directory,
        julia_bin, log_dir, auto_start, scope
    )
    
    # Write plist file
    try
        write(plist_path, plist_content)
        println("✓ Plist created: $plist_path")
    catch e
        error("Failed to write plist: $e")
    end
    
    # Set permissions
    if scope == :system
        run(`chmod 644 $plist_path`)
        run(`chown root:wheel $plist_path`)
    else
        run(`chmod 644 $plist_path`)
    end
    
    println("✓ Service installed")
    
    # Load service
    if auto_start
        try
            load_service(label, scope)
            println("✓ Service loaded and started")
        catch e
            @warn "Failed to load service: $e"
            println("Load manually with: launchctl load $plist_path")
        end
    end
    
    println("\n" * "=" ^ 70)
    println("INSTALLATION COMPLETE")
    println("=" ^ 70)
    println("\nService management:")
    println("  Load:     launchctl load $plist_path")
    println("  Unload:   launchctl unload $plist_path")
    println("  Start:    launchctl start $label")
    println("  Stop:     launchctl stop $label")
    println("  Status:   launchctl list | grep autoscheduler")
    println("\nLogs:")
    println("  Stdout:   $log_dir/stdout.log")
    println("  Stderr:   $log_dir/stderr.log")
    println("\nAPI endpoints:")
    println("  REST API: http://localhost:$rest_port")
    println("  WebSocket: ws://localhost:$ws_port")
    println("=" ^ 70)
    
    return true
end

"""
    uninstall_launchd_service(; scope=:user)

Uninstall AutoScheduler launchd service.
"""
function uninstall_launchd_service(; scope::Symbol=:user)
    println("Uninstalling AutoScheduler launchd service...")
    
    if scope == :system && !is_root()
        error("System-wide uninstallation requires root privileges. Run with sudo.")
    end
    
    label = SERVICE_LABEL
    plist_dir = scope == :system ? SYSTEM_DAEMONS_DIR : USER_AGENTS_DIR
    plist_path = joinpath(plist_dir, "$label.plist")
    
    # Stop and unload service
    try
        unload_service(label, scope)
        println("✓ Service unloaded")
    catch e
        @warn "Service may not be loaded: $e"
    end
    
    # Remove plist
    if isfile(plist_path)
        try
            rm(plist_path)
            println("✓ Plist removed: $plist_path")
        catch e
            @warn "Failed to remove plist: $e"
        end
    end
    
    println("✓ Uninstallation complete")
    
    return true
end

"""
    start_launchd_service(; scope=:user)

Start the AutoScheduler launchd service.
"""
function start_launchd_service(; scope::Symbol=:user)
    label = SERVICE_LABEL
    
    try
        if scope == :system
            run(`launchctl start $label`)
        else
            run(`launchctl start $label`)
        end
        println("✓ Service started")
        sleep(1)
        get_launchd_status(scope=scope)
        return true
    catch e
        @error "Failed to start service" exception=e
        return false
    end
end

"""
    stop_launchd_service(; scope=:user)

Stop the AutoScheduler launchd service.
"""
function stop_launchd_service(; scope::Symbol=:user)
    label = SERVICE_LABEL
    
    try
        if scope == :system
            run(`launchctl stop $label`)
        else
            run(`launchctl stop $label`)
        end
        println("✓ Service stopped")
        return true
    catch e
        @error "Failed to stop service" exception=e
        return false
    end
end

"""
    restart_launchd_service(; scope=:user)

Restart the AutoScheduler launchd service.
"""
function restart_launchd_service(; scope::Symbol=:user)
    println("Restarting service...")
    stop_launchd_service(scope=scope)
    sleep(2)
    start_launchd_service(scope=scope)
end

"""
    get_launchd_status(; scope=:user)

Get current service status.
"""
function get_launchd_status(; scope::Symbol=:user)
    label = SERVICE_LABEL
    
    try
        output = read(`launchctl list`, String)
        
        if occursin(label, output)
            println("✓ Service is loaded")
            
            # Extract PID and status
            for line in split(output, '\n')
                if occursin(label, line)
                    println("  $line")
                end
            end
        else
            println("✗ Service is not loaded")
        end
    catch e
        @error "Failed to get status" exception=e
    end
end

"""
    view_launchd_logs(; scope=:user, lines=50, stderr=false)

View service logs.
"""
function view_launchd_logs(; scope::Symbol=:user, lines::Int=50, stderr::Bool=false)
    log_dir = scope == :system ? SYSTEM_LOG_DIR : USER_LOG_DIR
    log_file = stderr ? joinpath(log_dir, "stderr.log") : joinpath(log_dir, "stdout.log")
    
    if isfile(log_file)
        try
            run(`tail -n $lines $log_file`)
        catch e
            @error "Failed to read log file" exception=e
        end
    else
        println("Log file not found: $log_file")
    end
end

# ============================================================================
# Internal Helper Functions
# ============================================================================

function is_root()::Bool
    return get(ENV, "USER", "") == "root" || geteuid() == 0
end

function geteuid()::Int
    try
        return parse(Int, read(`id -u`, String))
    catch
        return -1
    end
end

function setup_directories(plist_dir::String, log_dir::String, scope::Symbol)
    # Create LaunchAgents/LaunchDaemons directory
    if !isdir(plist_dir)
        try
            mkpath(plist_dir)
            println("✓ Created directory: $plist_dir")
        catch e
            error("Failed to create directory $plist_dir: $e")
        end
    end
    
    # Create log directory
    if !isdir(log_dir)
        try
            mkpath(log_dir)
            println("✓ Created log directory: $log_dir")
        catch e
            error("Failed to create log directory $log_dir: $e")
        end
    end
    
    # Set permissions
    if scope == :system
        try
            run(`chmod 755 $log_dir`)
        catch
        end
    end
end

function generate_launchd_plist(
    label::String,
    rest_port::Int,
    ws_port::Int,
    working_directory::String,
    julia_bin::String,
    log_dir::String,
    auto_start::Bool,
    scope::Symbol
)::String
    
    # Construct Julia command
    julia_cmd = """$julia_bin --project=$working_directory -e 'using AutoScheduler; config = DaemonManager.DaemonConfig(rest_port=$rest_port, ws_port=$ws_port, log_file=\"$log_dir/autoscheduler.log\", pid_file=\"$log_dir/autoscheduler.pid\", monitor_interval=1.0, auto_optimize=false); DaemonManager.deploy_daemon(config)'"""
    
    # Escape special characters for XML
    julia_cmd_escaped = replace(julia_cmd, 
        "&" => "&amp;",
        "<" => "&lt;",
        ">" => "&gt;",
        "\"" => "&quot;",
        "'" => "&apos;"
    )
    
    plist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$julia_bin</string>
        <string>--project=$working_directory</string>
        <string>-e</string>
        <string>using AutoScheduler; config = DaemonManager.DaemonConfig(rest_port=$rest_port, ws_port=$ws_port, log_file=\"$log_dir/autoscheduler.log\", pid_file=\"$log_dir/autoscheduler.pid\", monitor_interval=1.0, auto_optimize=false); DaemonManager.deploy_daemon(config)</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>$working_directory</string>
    
    <key>RunAtLoad</key>
    <$(auto_start ? "true" : "false")/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$log_dir/stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$log_dir/stderr.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>JULIA_NUM_THREADS</key>
        <string>$(Sys.CPU_THREADS)</string>
        <key>JULIA_PROJECT</key>
        <string>$working_directory</string>
    </dict>
    
    <key>ProcessType</key>
    <string>$(scope == :system ? "Background" : "Interactive")</string>
    
    <key>ThrottleInterval</key>
    <integer>10</integer>
    
    <key>ExitTimeOut</key>
    <integer>30</integer>
    
    <key>HardResourceLimits</key>
    <dict>
        <key>NumberOfFiles</key>
        <integer>4096</integer>
    </dict>
    
    <key>SoftResourceLimits</key>
    <dict>
        <key>NumberOfFiles</key>
        <integer>2048</integer>
    </dict>
</dict>
</plist>
"""
    
    return plist
end

function load_service(label::String, scope::Symbol)
    plist_dir = scope == :system ? SYSTEM_DAEMONS_DIR : USER_AGENTS_DIR
    plist_path = joinpath(plist_dir, "$label.plist")
    
    if scope == :system
        run(`launchctl load -w $plist_path`)
    else
        run(`launchctl load -w $plist_path`)
    end
end

function unload_service(label::String, scope::Symbol)
    plist_dir = scope == :system ? SYSTEM_DAEMONS_DIR : USER_AGENTS_DIR
    plist_path = joinpath(plist_dir, "$label.plist")
    
    if scope == :system
        run(`launchctl unload $plist_path`)
    else
        run(`launchctl unload $plist_path`)
    end
end

"""
    create_uninstall_script(; scope=:user)

Create an uninstall script for easy removal.
"""
function create_uninstall_script(; scope::Symbol=:user)
    script_path = if scope == :system
        "/usr/local/bin/uninstall-autoscheduler"
    else
        expanduser("~/bin/uninstall-autoscheduler")
    end
    
    script_content = """
#!/bin/bash
# AutoScheduler Uninstaller

echo "Uninstalling AutoScheduler..."

# Stop and unload service
launchctl unload ~/Library/LaunchAgents/$SERVICE_LABEL.plist 2>/dev/null || true
launchctl unload /Library/LaunchDaemons/$SERVICE_LABEL.plist 2>/dev/null || true

# Remove plist
rm -f ~/Library/LaunchAgents/$SERVICE_LABEL.plist
rm -f /Library/LaunchDaemons/$SERVICE_LABEL.plist

# Remove logs (optional)
# rm -rf ~/Library/Logs/AutoScheduler
# rm -rf /var/log/autoscheduler

echo "✓ Uninstallation complete"
"""
    
    try
        # Create bin directory if needed
        bin_dir = dirname(script_path)
        if !isdir(bin_dir)
            mkpath(bin_dir)
        end
        
        write(script_path, script_content)
        run(`chmod +x $script_path`)
        println("✓ Uninstall script created: $script_path")
    catch e
        @warn "Failed to create uninstall script: $e"
    end
end

end # module LaunchdService
