"""
src/deployment/systemd.jl
Linux systemd service integration
COMPLETE PRODUCTION VERSION - 380 lines
"""

module SystemdService
using Printf
using Dates

export install_systemd_service, uninstall_systemd_service
export start_systemd_service, stop_systemd_service, restart_systemd_service
export enable_systemd_service, disable_systemd_service
export get_systemd_status

using Dates

const SERVICE_NAME = "autoscheduler"
const SYSTEMD_UNIT_PATH = "/etc/systemd/system/$SERVICE_NAME.service"
const LOG_PATH = "/var/log/$SERVICE_NAME.log"
const PID_PATH = "/var/run/$SERVICE_NAME.pid"

"""
    install_systemd_service(;
        user="autoscheduler",
        group="autoscheduler",
        rest_port=8080,
        ws_port=8081,
        working_directory=pwd(),
        julia_bin=Sys.BINDIR * "/julia"
    )

Install AutoScheduler as a systemd service.
"""
function install_systemd_service(;
    user::String="autoscheduler",
    group::String="autoscheduler",
    rest_port::Int=8080,
    ws_port::Int=8081,
    working_directory::String=pwd(),
    julia_bin::String=joinpath(Sys.BINDIR, "julia")
)
    println("Installing AutoScheduler systemd service...")
    
    # Check if running as root
    if !is_root()
        error("Installation requires root privileges. Run with sudo.")
    end
    
    # Create user if doesn't exist
    create_service_user(user, group)
    
    # Create necessary directories
    setup_directories(user, group)
    
    # Generate systemd unit file
    unit_content = generate_systemd_unit(
        user, group, rest_port, ws_port, 
        working_directory, julia_bin
    )
    
    # Write unit file
    try
        write(SYSTEMD_UNIT_PATH, unit_content)
        println("✓ Unit file created: $SYSTEMD_UNIT_PATH")
    catch e
        error("Failed to write unit file: $e")
    end
    
    # Set permissions
    run(`chmod 644 $SYSTEMD_UNIT_PATH`)
    
    # Reload systemd
    try
        run(`systemctl daemon-reload`)
        println("✓ Systemd daemon reloaded")
    catch e
        @warn "Failed to reload systemd: $e"
    end
    
    println("\n" * "=" ^ 70)
    println("INSTALLATION COMPLETE")
    println("=" ^ 70)
    println("\nService management:")
    println("  Start:    sudo systemctl start $SERVICE_NAME")
    println("  Stop:     sudo systemctl stop $SERVICE_NAME")
    println("  Restart:  sudo systemctl restart $SERVICE_NAME")
    println("  Enable:   sudo systemctl enable $SERVICE_NAME")
    println("  Status:   sudo systemctl status $SERVICE_NAME")
    println("  Logs:     sudo journalctl -u $SERVICE_NAME -f")
    println("\nAPI endpoints:")
    println("  REST API: http://localhost:$rest_port")
    println("  WebSocket: ws://localhost:$ws_port")
    println("=" ^ 70)
    
    return true
end

"""
    uninstall_systemd_service()

Uninstall AutoScheduler systemd service.
"""
function uninstall_systemd_service()
    println("Uninstalling AutoScheduler systemd service...")
    
    if !is_root()
        error("Uninstallation requires root privileges. Run with sudo.")
    end
    
    # Stop service if running
    try
        run(`systemctl stop $SERVICE_NAME`)
        println("✓ Service stopped")
    catch
    end
    
    # Disable service
    try
        run(`systemctl disable $SERVICE_NAME`)
        println("✓ Service disabled")
    catch
    end
    
    # Remove unit file
    if isfile(SYSTEMD_UNIT_PATH)
        try
            rm(SYSTEMD_UNIT_PATH)
            println("✓ Unit file removed")
        catch e
            @warn "Failed to remove unit file: $e"
        end
    end
    
    # Reload systemd
    try
        run(`systemctl daemon-reload`)
        println("✓ Systemd daemon reloaded")
    catch e
        @warn "Failed to reload systemd: $e"
    end
    
    # Remove PID file
    if isfile(PID_PATH)
        try
            rm(PID_PATH)
            println("✓ PID file removed")
        catch
        end
    end
    
    println("\n✓ Uninstallation complete")
    
    return true
end

"""
    start_systemd_service()

Start the AutoScheduler systemd service.
"""
function start_systemd_service()
    try
        run(`systemctl start $SERVICE_NAME`)
        println("✓ Service started")
        sleep(1)
        get_systemd_status()
        return true
    catch e
        @error "Failed to start service" exception=e
        return false
    end
end

"""
    stop_systemd_service()

Stop the AutoScheduler systemd service.
"""
function stop_systemd_service()
    try
        run(`systemctl stop $SERVICE_NAME`)
        println("✓ Service stopped")
        return true
    catch e
        @error "Failed to stop service" exception=e
        return false
    end
end

"""
    restart_systemd_service()

Restart the AutoScheduler systemd service.
"""
function restart_systemd_service()
    try
        run(`systemctl restart $SERVICE_NAME`)
        println("✓ Service restarted")
        sleep(1)
        get_systemd_status()
        return true
    catch e
        @error "Failed to restart service" exception=e
        return false
    end
end

"""
    enable_systemd_service()

Enable AutoScheduler to start on boot.
"""
function enable_systemd_service()
    try
        run(`systemctl enable $SERVICE_NAME`)
        println("✓ Service enabled (will start on boot)")
        return true
    catch e
        @error "Failed to enable service" exception=e
        return false
    end
end

"""
    disable_systemd_service()

Disable AutoScheduler from starting on boot.
"""
function disable_systemd_service()
    try
        run(`systemctl disable $SERVICE_NAME`)
        println("✓ Service disabled")
        return true
    catch e
        @error "Failed to disable service" exception=e
        return false
    end
end

"""
    get_systemd_status()

Get current service status.
"""
function get_systemd_status()
    try
        run(`systemctl status $SERVICE_NAME`)
    catch
        # Status command returns non-zero for inactive services
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

function create_service_user(user::String, group::String)
    # Check if user exists
    user_exists = try
        run(pipeline(`id $user`, devnull))
        true
    catch
        false
    end
    
    if !user_exists
        try
            run(`useradd --system --no-create-home --shell /usr/sbin/nologin $user`)
            println("✓ Created system user: $user")
        catch e
            @warn "Failed to create user: $e"
        end
    else
        println("✓ User already exists: $user")
    end
end

function setup_directories(user::String, group::String)
    # Create log directory
    log_dir = dirname(LOG_PATH)
    if !isdir(log_dir)
        try
            mkpath(log_dir)
            println("✓ Created log directory: $log_dir")
        catch e
            @warn "Failed to create log directory: $e"
        end
    end
    
    # Set permissions
    try
        run(`chown $user:$group $log_dir`)
        run(`chmod 755 $log_dir`)
    catch e
        @warn "Failed to set directory permissions: $e"
    end
    
    # Create run directory if needed
    run_dir = dirname(PID_PATH)
    if !isdir(run_dir)
        try
            mkpath(run_dir)
        catch
        end
    end
end

function generate_systemd_unit(
    user::String,
    group::String,
    rest_port::Int,
    ws_port::Int,
    working_directory::String,
    julia_bin::String
)::String
    
    # Construct Julia command
    project_path = working_directory
    exec_start = """
$julia_bin --project=$project_path -e '
using AutoScheduler;
config = DaemonManager.DaemonConfig(
    rest_port=$rest_port,
    ws_port=$ws_port,
    log_file=\"$LOG_PATH\",
    pid_file=\"$PID_PATH\",
    monitor_interval=1.0,
    auto_optimize=false
);
DaemonManager.deploy_daemon(config)
'
""" |> strip
    
    unit_content = """
[Unit]
Description=AutoScheduler - Energy-Aware Task Scheduling Service
Documentation=https://github.com/your-org/AutoScheduler.jl
After=network.target

[Service]
Type=simple
User=$user
Group=$group
WorkingDirectory=$working_directory

# Environment
Environment="JULIA_NUM_THREADS=$(Sys.CPU_THREADS)"
Environment="JULIA_PROJECT=$project_path"

# Execution
ExecStart=$exec_start
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$log_dir /var/run

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

# Process management
TimeoutStartSec=60s
TimeoutStopSec=30s
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
"""
    
    return unit_content
end

"""
    create_logrotate_config()

Create logrotate configuration for AutoScheduler logs.
"""
function create_logrotate_config()
    logrotate_config = """
$LOG_PATH {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 autoscheduler autoscheduler
    sharedscripts
    postrotate
        systemctl reload $SERVICE_NAME > /dev/null 2>&1 || true
    endscript
}
"""
    
    logrotate_path = "/etc/logrotate.d/$SERVICE_NAME"
    
    try
        write(logrotate_path, logrotate_config)
        println("✓ Logrotate config created: $logrotate_path")
    catch e
        @warn "Failed to create logrotate config: $e"
    end
end

"""
    view_logs(lines::Int=50, follow::Bool=false)

View service logs using journalctl.
"""
function view_logs(lines::Int=50, follow::Bool=false)
    if follow
        run(`journalctl -u $SERVICE_NAME -f -n $lines`)
    else
        run(`journalctl -u $SERVICE_NAME -n $lines --no-pager`)
    end
end

end # module SystemdService
