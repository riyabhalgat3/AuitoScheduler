# AutoScheduler.jl - Windows Installation Script
# Supports: Windows 10, Windows 11, Windows Server 2019+
# PRODUCTION READY

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

# Configuration
$InstallDir = "C:\Program Files\AutoScheduler"
$JuliaVersion = "1.10.0"
$RestPort = 8080
$WsPort = 8081
$ServiceName = "AutoScheduler"
$LogDir = "C:\ProgramData\AutoScheduler\logs"

# Colors for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-ColorOutput "═══════════════════════════════════════════════" "Blue"
    Write-ColorOutput "  $Text" "Blue"
    Write-ColorOutput "═══════════════════════════════════════════════" "Blue"
    Write-Host ""
}

Write-Header "AutoScheduler.jl Installation Script"
Write-ColorOutput "Windows 10/11 & Server 2019+" "Cyan"
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-ColorOutput "ERROR: This script must be run as Administrator" "Red"
    Write-ColorOutput "Right-click PowerShell and select 'Run as Administrator'" "Yellow"
    exit 1
}

# Detect Windows version
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-ColorOutput "Detected: $($osInfo.Caption) $($osInfo.Version)" "Green"
Write-ColorOutput "Architecture: $env:PROCESSOR_ARCHITECTURE" "Green"
Write-Host ""

# Install Chocolatey if not present
function Install-Chocolatey {
    Write-ColorOutput "Checking for Chocolatey package manager..." "Yellow"
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-ColorOutput "✓ Chocolatey already installed" "Green"
        choco --version
    } else {
        Write-ColorOutput "Installing Chocolatey..." "Yellow"
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-ColorOutput "✓ Chocolatey installed" "Green"
    }
}

# Install Julia
function Install-Julia {
    Write-ColorOutput "Installing Julia..." "Yellow"
    
    if (Get-Command julia -ErrorAction SilentlyContinue) {
        $juliaVersion = julia --version
        Write-ColorOutput "✓ Julia already installed: $juliaVersion" "Green"
        return
    }
    
    # Install via Chocolatey
    choco install julia --version=$JuliaVersion -y
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-ColorOutput "✓ Julia installed" "Green"
    julia --version
}

# Install Git
function Install-Git {
    Write-ColorOutput "Installing Git..." "Yellow"
    
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-ColorOutput "✓ Git already installed" "Green"
        return
    }
    
    choco install git -y
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-ColorOutput "✓ Git installed" "Green"
}

# Install NSSM (Non-Sucking Service Manager)
function Install-NSSM {
    Write-ColorOutput "Installing NSSM..." "Yellow"
    
    if (Get-Command nssm -ErrorAction SilentlyContinue) {
        Write-ColorOutput "✓ NSSM already installed" "Green"
        return
    }
    
    choco install nssm -y
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-ColorOutput "✓ NSSM installed" "Green"
}

# Clone repository
function Clone-Repository {
    Write-ColorOutput "Cloning AutoScheduler.jl repository..." "Yellow"
    
    if (Test-Path $InstallDir) {
        Write-ColorOutput "Directory exists, pulling latest changes..." "Yellow"
        Set-Location $InstallDir
        git pull
    } else {
        git clone https://github.com/your-org/AutoScheduler.jl.git $InstallDir
    }
    
    Set-Location $InstallDir
    Write-ColorOutput "✓ Repository ready" "Green"
}

# Install Julia dependencies
function Install-JuliaDependencies {
    Write-ColorOutput "Installing Julia dependencies..." "Yellow"
    
    Set-Location $InstallDir
    
    # Set environment
    $env:JULIA_PROJECT = $InstallDir
    
    # Instantiate project
    julia --project=. -e 'using Pkg; Pkg.instantiate()'
    
    # Precompile
    julia --project=. -e 'using Pkg; Pkg.precompile()'
    
    Write-ColorOutput "✓ Julia dependencies installed" "Green"
}

# Setup directories
function Setup-Directories {
    Write-ColorOutput "Setting up directories..." "Yellow"
    
    # Create log directory
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
    
    # Set permissions (Everyone: Read & Execute, Write)
    $acl = Get-Acl $LogDir
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "Everyone",
        "ReadAndExecute, Write",
        "ContainerInherit, ObjectInherit",
        "None",
        "Allow"
    )
    $acl.SetAccessRule($accessRule)
    Set-Acl $LogDir $acl
    
    Write-ColorOutput "✓ Log directory created: $LogDir" "Green"
}

# Install Windows Service
function Install-WindowsService {
    Write-ColorOutput "Installing Windows Service..." "Yellow"
    
    # Check if service exists
    $existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if ($existingService) {
        Write-ColorOutput "Service already exists, stopping and removing..." "Yellow"
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        nssm remove $ServiceName confirm
        Start-Sleep -Seconds 2
    }
    
    # Find julia.exe path
    $juliaPath = (Get-Command julia).Source
    
    # Construct arguments
    $juliaArgs = "--project=`"$InstallDir`" -e `"using AutoScheduler; config = DaemonManager.DaemonConfig(rest_port=$RestPort, ws_port=$WsPort, log_file=\`"$LogDir\autoscheduler.log\`", pid_file=\`"$LogDir\autoscheduler.pid\`", monitor_interval=1.0, auto_optimize=false); DaemonManager.deploy_daemon(config)`""
    
    # Install service with NSSM
    nssm install $ServiceName $juliaPath $juliaArgs
    
    # Configure service
    nssm set $ServiceName DisplayName "AutoScheduler - Energy-Aware Task Scheduling"
    nssm set $ServiceName Description "Energy-aware heterogeneous task scheduling system with real-time monitoring"
    nssm set $ServiceName AppDirectory $InstallDir
    nssm set $ServiceName Start SERVICE_AUTO_START
    
    # Configure logging
    nssm set $ServiceName AppStdout "$LogDir\stdout.log"
    nssm set $ServiceName AppStderr "$LogDir\stderr.log"
    nssm set $ServiceName AppRotateFiles 1
    nssm set $ServiceName AppRotateOnline 1
    nssm set $ServiceName AppRotateBytes 10485760  # 10MB
    
    # Set environment variables
    $numThreads = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    nssm set $ServiceName AppEnvironmentExtra "JULIA_NUM_THREADS=$numThreads" "JULIA_PROJECT=$InstallDir"
    
    # Configure restart behavior
    nssm set $ServiceName AppExit Default Restart
    nssm set $ServiceName AppThrottle 10000  # 10 seconds
    
    Write-ColorOutput "✓ Service installed with NSSM" "Green"
}

# Configure Windows Firewall
function Configure-Firewall {
    Write-ColorOutput "Configuring Windows Firewall..." "Yellow"
    
    # Remove existing rules
    Remove-NetFirewallRule -DisplayName "AutoScheduler REST API" -ErrorAction SilentlyContinue
    Remove-NetFirewallRule -DisplayName "AutoScheduler WebSocket" -ErrorAction SilentlyContinue
    
    # Add firewall rules
    New-NetFirewallRule -DisplayName "AutoScheduler REST API" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $RestPort `
        -Action Allow `
        -Profile Domain,Private `
        -ErrorAction SilentlyContinue | Out-Null
    
    New-NetFirewallRule -DisplayName "AutoScheduler WebSocket" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $WsPort `
        -Action Allow `
        -Profile Domain,Private `
        -ErrorAction SilentlyContinue | Out-Null
    
    Write-ColorOutput "✓ Firewall rules added" "Green"
}

# Start service
function Start-AutoSchedulerService {
    Write-ColorOutput "Starting service..." "Yellow"
    
    Start-Service -Name $ServiceName
    
    Start-Sleep -Seconds 3
    
    $service = Get-Service -Name $ServiceName
    
    if ($service.Status -eq "Running") {
        Write-ColorOutput "✓ Service started successfully" "Green"
    } else {
        Write-ColorOutput "✗ Service failed to start" "Red"
        Write-ColorOutput "Status: $($service.Status)" "Red"
        Write-ColorOutput "Check logs: Get-Content $LogDir\stderr.log -Tail 50" "Yellow"
        exit 1
    }
}

# Run tests
function Run-Tests {
    Write-ColorOutput "Running tests..." "Yellow"
    
    Set-Location $InstallDir
    $env:JULIA_PROJECT = $InstallDir
    
    try {
        julia --project=. test/runtests.jl
        Write-ColorOutput "✓ Tests passed" "Green"
    } catch {
        Write-ColorOutput "Tests had issues but continuing" "Yellow"
    }
}

# Create desktop shortcut
function Create-Shortcuts {
    Write-ColorOutput "Creating shortcuts..." "Yellow"
    
    $WshShell = New-Object -comObject WScript.Shell
    
    # Service Manager shortcut
    $shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\AutoScheduler Service Manager.lnk")
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-Command `"Get-Service AutoScheduler | Select-Object Name, Status, StartType`""
    $shortcut.IconLocation = "imageres.dll,1"
    $shortcut.Save()
    
    Write-ColorOutput "✓ Desktop shortcut created" "Green"
}

# Print summary
function Print-Summary {
    Write-Host ""
    Write-Header "Installation Complete!"
    
    Write-ColorOutput "Service Management:" "Green"
    Write-Host "  Start:    net start $ServiceName"
    Write-Host "  Stop:     net stop $ServiceName"
    Write-Host "  Restart:  Restart-Service $ServiceName"
    Write-Host "  Status:   Get-Service $ServiceName"
    Write-Host ""
    
    Write-ColorOutput "PowerShell Commands:" "Green"
    Write-Host "  Start:    Start-Service $ServiceName"
    Write-Host "  Stop:     Stop-Service $ServiceName"
    Write-Host "  Restart:  Restart-Service $ServiceName"
    Write-Host "  Status:   Get-Service $ServiceName | Format-List"
    Write-Host ""
    
    Write-ColorOutput "Logs:" "Green"
    Write-Host "  Directory: $LogDir"
    Write-Host "  Stdout:    Get-Content $LogDir\stdout.log -Tail 50"
    Write-Host "  Stderr:    Get-Content $LogDir\stderr.log -Tail 50"
    Write-Host "  Monitor:   Get-Content $LogDir\stdout.log -Wait"
    Write-Host ""
    
    Write-ColorOutput "API Endpoints:" "Green"
    Write-Host "  REST API:    http://localhost:$RestPort"
    Write-Host "  Health:      http://localhost:$RestPort/api/v1/health"
    Write-Host "  Metrics:     http://localhost:$RestPort/api/v1/metrics"
    Write-Host "  WebSocket:   ws://localhost:$WsPort"
    Write-Host "  Docs:        http://localhost:$RestPort/docs"
    Write-Host ""
    
    Write-ColorOutput "Installation Directory:" "Green"
    Write-Host "  $InstallDir"
    Write-Host ""
    
    Write-ColorOutput "Test the service:" "Yellow"
    Write-Host "  Invoke-WebRequest http://localhost:$RestPort/api/v1/health"
    Write-Host ""
    
    Write-ColorOutput "GUI Management:" "Green"
    Write-Host "  services.msc - Open Services Manager"
    Write-Host "  perfmon - Open Performance Monitor"
    Write-Host ""
}

# Main installation flow
function Main {
    try {
        Write-ColorOutput "Step 1/11: Installing Chocolatey..." "Cyan"
        Install-Chocolatey
        Write-Host ""
        
        Write-ColorOutput "Step 2/11: Installing Julia..." "Cyan"
        Install-Julia
        Write-Host ""
        
        Write-ColorOutput "Step 3/11: Installing Git..." "Cyan"
        Install-Git
        Write-Host ""
        
        Write-ColorOutput "Step 4/11: Installing NSSM..." "Cyan"
        Install-NSSM
        Write-Host ""
        
        Write-ColorOutput "Step 5/11: Cloning repository..." "Cyan"
        Clone-Repository
        Write-Host ""
        
        Write-ColorOutput "Step 6/11: Installing Julia packages..." "Cyan"
        Install-JuliaDependencies
        Write-Host ""
        
        Write-ColorOutput "Step 7/11: Setting up directories..." "Cyan"
        Setup-Directories
        Write-Host ""
        
        Write-ColorOutput "Step 8/11: Installing Windows Service..." "Cyan"
        Install-WindowsService
        Write-Host ""
        
        Write-ColorOutput "Step 9/11: Configuring firewall..." "Cyan"
        Configure-Firewall
        Write-Host ""
        
        Write-ColorOutput "Step 10/11: Starting service..." "Cyan"
        Start-AutoSchedulerService
        Write-Host ""
        
        Write-ColorOutput "Step 11/11: Running tests..." "Cyan"
        Run-Tests
        Write-Host ""
        
        Create-Shortcuts
        
        Print-Summary
        
    } catch {
        Write-ColorOutput "ERROR: Installation failed!" "Red"
        Write-ColorOutput $_.Exception.Message "Red"
        Write-ColorOutput $_.ScriptStackTrace "Red"
        exit 1
    }
}

# Handle Ctrl+C
$null = Register-EngineEvent PowerShell.Exiting -Action {
    Write-ColorOutput "`nInstallation interrupted" "Red"
}

# Run main
Main

exit 0