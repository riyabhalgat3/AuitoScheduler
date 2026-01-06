"""
src/deployment/windows_service.jl
Windows Service integration using NSSM (Non-Sucking Service Manager)
COMPLETE PRODUCTION VERSION - 450 lines
"""

module WindowsService
using Printf
using Dates

export install_windows_service, uninstall_windows_service
export start_windows_service, stop_windows_service, restart_windows_service
export get_windows_service_status
export download_nssm, is_nssm_installed

const SERVICE_NAME = "AutoScheduler"
const SERVICE_DISPLAY_NAME = "AutoScheduler - Energy-Aware Task Scheduling"
const SERVICE_DESCRIPTION = "Energy-aware heterogeneous task scheduling system with real-time monitoring"
const LOG_DIR = "C:\\ProgramData\\AutoScheduler\\logs"
const NSSM_URL = "https://nssm.cc/release/nssm-2.24.zip"
const NSSM_INSTALL_DIR = "C:\\Program Files\\NSSM"

"""
    install_windows_service(;
        rest_port=8080,
        ws_port=8081,
        working_directory=pwd(),
        julia_bin=joinpath(Sys.BINDIR, "julia.exe"),
        auto_start=true,
        use_nssm=true
    )

Install AutoScheduler as a Windows Service.

# Arguments
- `rest_port::Int` - REST API port
- `ws_port::Int` - WebSocket port  
- `working_directory::String` - Working directory path
- `julia_bin::String` - Path to julia.exe
- `auto_start::Bool` - Start service automatically on boot
- `use_nssm::Bool` - Use NSSM (recommended) or sc.exe

# Note
Requires Administrator privileges.
"""
function install_windows_service(;
    rest_port::Int=8080,
    ws_port::Int=8081,
    working_directory::String=pwd(),
    julia_bin::String=joinpath(Sys.BINDIR, "julia.exe"),
    auto_start::Bool=true,
    use_nssm::Bool=true
)
    println("Installing AutoScheduler Windows Service...")
    
    # Check if running as Administrator
    if !is_admin()
        error("Installation requires Administrator privileges. Run PowerShell as Administrator.")
    end
    
    # Create directories
    setup_directories()
    
    if use_nssm
        # Install using NSSM (recommended)
        install_with_nssm(rest_port, ws_port, working_directory, julia_bin, auto_start)
    else
        # Install using sc.exe (Windows built-in)
        install_with_sc(rest_port, ws_port, working_directory, julia_bin, auto_start)
    end
    
    println("\n" * "=" ^ 70)
    println("INSTALLATION COMPLETE")
    println("=" ^ 70)
    println("\nService management:")
    println("  Start:    net start $SERVICE_NAME")
    println("  Stop:     net stop $SERVICE_NAME")
    println("  Restart:  net stop $SERVICE_NAME && net start $SERVICE_NAME")
    println("  Status:   sc query $SERVICE_NAME")
    println("\nPowerShell commands:")
    println("  Start:    Start-Service $SERVICE_NAME")
    println("  Stop:     Stop-Service $SERVICE_NAME")
    println("  Restart:  Restart-Service $SERVICE_NAME")
    println("  Status:   Get-Service $SERVICE_NAME")
    println("\nLogs:")
    println("  Directory: $LOG_DIR")
    println("\nAPI endpoints:")
    println("  REST API: http://localhost:$rest_port")
    println("  WebSocket: ws://localhost:$ws_port")
    println("=" ^ 70)
    
    return true
end

"""
    uninstall_windows_service(; use_nssm=true)

Uninstall AutoScheduler Windows Service.
"""
function uninstall_windows_service(; use_nssm::Bool=true)
    println("Uninstalling AutoScheduler Windows Service...")
    
    if !is_admin()
        error("Uninstallation requires Administrator privileges.")
    end
    
    # Stop service first
    try
        stop_windows_service()
        sleep(2)
    catch
    end
    
    if use_nssm && is_nssm_installed()
        # Uninstall using NSSM
        uninstall_with_nssm()
    else
        # Uninstall using sc.exe
        uninstall_with_sc()
    end
    
    println("✓ Uninstallation complete")
    
    return true
end

"""
    start_windows_service()

Start the AutoScheduler Windows Service.
"""
function start_windows_service()
    try
        run(`net start $SERVICE_NAME`)
        println("✓ Service started")
        sleep(2)
        get_windows_service_status()
        return true
    catch e
        @error "Failed to start service" exception=e
        return false
    end
end

"""
    stop_windows_service()

Stop the AutoScheduler Windows Service.
"""
function stop_windows_service()
    try
        run(`net stop $SERVICE_NAME`)
        println("✓ Service stopped")
        return true
    catch e
        @error "Failed to stop service" exception=e
        return false
    end
end

"""
    restart_windows_service()

Restart the AutoScheduler Windows Service.
"""
function restart_windows_service()
    println("Restarting service...")
    stop_windows_service()
    sleep(3)
    start_windows_service()
end

"""
    get_windows_service_status()

Get current service status.
"""
function get_windows_service_status()
    try
        run(`sc query $SERVICE_NAME`)
    catch e
        println("Service not found or not accessible")
    end
end

# ============================================================================
# NSSM Installation (Recommended Method)
# ============================================================================

"""
    is_nssm_installed() -> Bool

Check if NSSM is installed.
"""
function is_nssm_installed()::Bool
    # Check common locations
    nssm_paths = [
        "C:\\Program Files\\NSSM\\nssm.exe",
        "C:\\nssm\\nssm.exe",
        joinpath(pwd(), "nssm.exe")
    ]
    
    for path in nssm_paths
        if isfile(path)
            return true
        end
    end
    
    # Check PATH
    try
        run(pipeline(`where nssm`, devnull))
        return true
    catch
        return false
    end
end

"""
    download_nssm()

Download and install NSSM.
"""
function download_nssm()
    println("Downloading NSSM...")
    
    if !is_admin()
        error("NSSM installation requires Administrator privileges")
    end
    
    # Create install directory
    if !isdir(NSSM_INSTALL_DIR)
        mkpath(NSSM_INSTALL_DIR)
    end
    
    # Download NSSM zip
    zip_path = joinpath(NSSM_INSTALL_DIR, "nssm.zip")
    
    try
        # Use PowerShell to download
        ps_cmd = """
        \$ProgressPreference = 'SilentlyContinue';
        Invoke-WebRequest -Uri '$NSSM_URL' -OutFile '$zip_path'
        """
        run(`powershell -Command $ps_cmd`)
        println("✓ Downloaded NSSM")
    catch e
        error("Failed to download NSSM: $e")
    end
    
    # Extract zip
    try
        ps_cmd = """
        Expand-Archive -Path '$zip_path' -DestinationPath '$NSSM_INSTALL_DIR' -Force
        """
        run(`powershell -Command $ps_cmd`)
        
        # Find nssm.exe in extracted folders
        # NSSM zip contains win32/win64 folders
        arch = Sys.ARCH == :x86_64 ? "win64" : "win32"
        nssm_exe_src = joinpath(NSSM_INSTALL_DIR, "nssm-2.24", arch, "nssm.exe")
        nssm_exe_dest = joinpath(NSSM_INSTALL_DIR, "nssm.exe")
        
        if isfile(nssm_exe_src)
            cp(nssm_exe_src, nssm_exe_dest, force=true)
        end
        
        # Add to PATH
        add_to_path(NSSM_INSTALL_DIR)
        
        println("✓ NSSM installed to $NSSM_INSTALL_DIR")
        
        # Cleanup
        rm(zip_path, force=true)
    catch e
        @warn "Failed to extract NSSM: $e"
    end
end

function install_with_nssm(
    rest_port::Int,
    ws_port::Int,
    working_directory::String,
    julia_bin::String,
    auto_start::Bool
)
    # Ensure NSSM is installed
    if !is_nssm_installed()
        println("NSSM not found. Installing...")
        download_nssm()
    end
    
    # Find NSSM executable
    nssm_exe = find_nssm_exe()
    
    if nssm_exe === nothing
        error("NSSM not found. Please install manually from https://nssm.cc/")
    end
    
    println("Using NSSM: $nssm_exe")
    
    # Construct Julia command
    julia_args = "--project=$working_directory -e \"using AutoScheduler; config = DaemonManager.DaemonConfig(rest_port=$rest_port, ws_port=$ws_port, log_file=\\\"$LOG_DIR\\\\autoscheduler.log\\\", pid_file=\\\"$LOG_DIR\\\\autoscheduler.pid\\\", monitor_interval=1.0, auto_optimize=false); DaemonManager.deploy_daemon(config)\""
    
    # Install service
    try
        run(`$nssm_exe install $SERVICE_NAME $julia_bin $julia_args`)
        println("✓ Service installed with NSSM")
    catch e
        error("Failed to install service with NSSM: $e")
    end
    
    # Configure service
    run(`$nssm_exe set $SERVICE_NAME DisplayName "$SERVICE_DISPLAY_NAME"`)
    run(`$nssm_exe set $SERVICE_NAME Description "$SERVICE_DESCRIPTION"`)
    run(`$nssm_exe set $SERVICE_NAME AppDirectory $working_directory`)
    
    # Set startup type
    startup_type = auto_start ? "SERVICE_AUTO_START" : "SERVICE_DEMAND_START"
    run(`$nssm_exe set $SERVICE_NAME Start $startup_type`)
    
    # Configure logging
    run(`$nssm_exe set $SERVICE_NAME AppStdout "$LOG_DIR\\stdout.log"`)
    run(`$nssm_exe set $SERVICE_NAME AppStderr "$LOG_DIR\\stderr.log"`)
    run(`$nssm_exe set $SERVICE_NAME AppRotateFiles 1`)
    run(`$nssm_exe set $SERVICE_NAME AppRotateOnline 1`)
    run(`$nssm_exe set $SERVICE_NAME AppRotateBytes 10485760`)  # 10MB
    
    # Set environment variables
    run(`$nssm_exe set $SERVICE_NAME AppEnvironmentExtra "JULIA_NUM_THREADS=$(Sys.CPU_THREADS)" "JULIA_PROJECT=$working_directory"`)
    
    # Configure restart behavior
    run(`$nssm_exe set $SERVICE_NAME AppExit Default Restart`)
    run(`$nssm_exe set $SERVICE_NAME AppThrottle 10000`)  # 10 seconds
    
    println("✓ Service configured")
    
    # Start service if auto_start
    if auto_start
        try
            start_windows_service()
        catch e
            @warn "Failed to start service: $e"
        end
    end
end

function uninstall_with_nssm()
    nssm_exe = find_nssm_exe()
    
    if nssm_exe === nothing
        @warn "NSSM not found, falling back to sc.exe"
        uninstall_with_sc()
        return
    end
    
    try
        run(`$nssm_exe remove $SERVICE_NAME confirm`)
        println("✓ Service uninstalled with NSSM")
    catch e
        error("Failed to uninstall service with NSSM: $e")
    end
end

# ============================================================================
# sc.exe Installation (Built-in Windows Method)
# ============================================================================

function install_with_sc(
    rest_port::Int,
    ws_port::Int,
    working_directory::String,
    julia_bin::String,
    auto_start::Bool
)
    println("Installing service with sc.exe...")
    
    # Create wrapper script
    wrapper_script = create_wrapper_script(
        rest_port, ws_port, working_directory, julia_bin
    )
    
    # Install service
    startup_type = auto_start ? "auto" : "demand"
    
    try
        run(`sc create $SERVICE_NAME binPath= $wrapper_script start= $startup_type DisplayName= "$SERVICE_DISPLAY_NAME"`)
        println("✓ Service created")
    catch e
        error("Failed to create service: $e")
    end
    
    # Set description
    try
        run(`sc description $SERVICE_NAME "$SERVICE_DESCRIPTION"`)
    catch
    end
    
    # Configure failure actions
    try
        run(`sc failure $SERVICE_NAME reset= 86400 actions= restart/60000/restart/60000/restart/60000`)
    catch
    end
    
    println("✓ Service configured")
    
    if auto_start
        try
            start_windows_service()
        catch e
            @warn "Failed to start service: $e"
        end
    end
end

function uninstall_with_sc()
    try
        run(`sc delete $SERVICE_NAME`)
        println("✓ Service deleted")
    catch e
        error("Failed to delete service: $e")
    end
end

function create_wrapper_script(
    rest_port::Int,
    ws_port::Int,
    working_directory::String,
    julia_bin::String
)::String
    script_path = joinpath(LOG_DIR, "autoscheduler_service.bat")
    
    script_content = """
@echo off
REM AutoScheduler Service Wrapper
REM This script is automatically generated

SET JULIA_NUM_THREADS=$(Sys.CPU_THREADS)
SET JULIA_PROJECT=$working_directory

"$julia_bin" --project=$working_directory -e "using AutoScheduler; config = DaemonManager.DaemonConfig(rest_port=$rest_port, ws_port=$ws_port, log_file=\\"$LOG_DIR\\\\autoscheduler.log\\", pid_file=\\"$LOG_DIR\\\\autoscheduler.pid\\", monitor_interval=1.0, auto_optimize=false); DaemonManager.deploy_daemon(config)"
"""
    
    write(script_path, script_content)
    println("✓ Wrapper script created: $script_path")
    
    return script_path
end

# ============================================================================
# Helper Functions
# ============================================================================

function is_admin()::Bool
    try
        ps_cmd = """
        \$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        \$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        """
        result = read(`powershell -Command $ps_cmd`, String)
        return strip(result) == "True"
    catch
        return false
    end
end

function setup_directories()
    if !isdir(LOG_DIR)
        try
            mkpath(LOG_DIR)
            println("✓ Created log directory: $LOG_DIR")
        catch e
            error("Failed to create log directory: $e")
        end
    end
end

function find_nssm_exe()
    # Check standard locations
    locations = [
        "C:\\Program Files\\NSSM\\nssm.exe",
        "C:\\nssm\\nssm.exe",
        joinpath(NSSM_INSTALL_DIR, "nssm.exe")
    ]
    
    for loc in locations
        if isfile(loc)
            return loc
        end
    end
    
    # Check PATH
    try
        result = read(`where nssm`, String)
        paths = split(strip(result), '\n')
        if !isempty(paths)
            return strip(paths[1])
        end
    catch
    end
    
    return nothing
end

function add_to_path(dir::String)
    try
        ps_cmd = """
        \$oldPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        if (\$oldPath -notlike "*$dir*") {
            \$newPath = \$oldPath + ";$dir"
            [Environment]::SetEnvironmentVariable('Path', \$newPath, 'Machine')
        }
        """
        run(`powershell -Command $ps_cmd`)
        println("✓ Added to system PATH")
    catch e
        @warn "Failed to add to PATH: $e"
    end
end

"""
    view_event_log(lines::Int=50)

View service logs from Windows Event Log.
"""
function view_event_log(lines::Int=50)
    try
        ps_cmd = """
        Get-EventLog -LogName Application -Source $SERVICE_NAME -Newest $lines | 
        Format-Table TimeGenerated, EntryType, Message -AutoSize
        """
        run(`powershell -Command $ps_cmd`)
    catch e
        println("No events found or access denied")
    end
end

end # module WindowsService
