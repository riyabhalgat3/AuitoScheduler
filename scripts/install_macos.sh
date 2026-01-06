#!/bin/bash
# AutoScheduler.jl - macOS Installation Script
# Supports: macOS 11+ (Big Sur and later), Intel and Apple Silicon
# PRODUCTION READY

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/AutoScheduler.jl"
JULIA_VERSION="1.10.0"
REST_PORT=8080
WS_PORT=8081
SCOPE="user"  # user or system

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AutoScheduler.jl Installation Script    ║${NC}"
echo -e "${BLUE}║   macOS (Intel & Apple Silicon)           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
echo -e "${GREEN}Architecture: $ARCH${NC}"

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo -e "${GREEN}macOS Version: $MACOS_VERSION${NC}"
echo ""

# Check if running as root (not recommended for user scope)
if [[ $EUID -eq 0 && "$SCOPE" == "user" ]]; then
   echo -e "${YELLOW}Warning: Running as root but installing for user scope${NC}"
   echo -e "${YELLOW}Consider running without sudo for user installation${NC}"
   read -p "Continue? (y/n) " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

# Install Homebrew if not present
install_homebrew() {
    echo -e "${YELLOW}Checking for Homebrew...${NC}"
    
    if command -v brew &> /dev/null; then
        echo -e "${GREEN}Homebrew already installed${NC}"
        brew --version
    else
        echo -e "${YELLOW}Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon
        if [[ "$ARCH" == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        echo -e "${GREEN}✓ Homebrew installed${NC}"
    fi
}

# Install Julia
install_julia() {
    echo -e "${YELLOW}Installing Julia...${NC}"
    
    if command -v julia &> /dev/null; then
        JULIA_CURRENT=$(julia --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo -e "${GREEN}Julia $JULIA_CURRENT already installed${NC}"
        return 0
    fi
    
    # Install via Homebrew
    brew install julia
    
    echo -e "${GREEN}✓ Julia installed${NC}"
    julia --version
}

# Install dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    
    # Install git if not present
    if ! command -v git &> /dev/null; then
        brew install git
    fi
    
    # Install useful monitoring tools
    brew install htop wget curl
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# Clone repository
clone_repository() {
    echo -e "${YELLOW}Cloning AutoScheduler.jl repository...${NC}"
    
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Directory exists, pulling latest changes...${NC}"
        cd "$INSTALL_DIR"
        git pull
    else
        git clone https://github.com/your-org/AutoScheduler.jl.git "$INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR"
    echo -e "${GREEN}✓ Repository ready${NC}"
}

# Install Julia dependencies
install_julia_deps() {
    echo -e "${YELLOW}Installing Julia dependencies...${NC}"
    
    cd "$INSTALL_DIR"
    
    # Instantiate project
    julia --project=. -e 'using Pkg; Pkg.instantiate()'
    
    # Precompile
    julia --project=. -e 'using Pkg; Pkg.precompile()'
    
    echo -e "${GREEN}✓ Julia dependencies installed${NC}"
}

# Setup directories
setup_directories() {
    echo -e "${YELLOW}Setting up directories...${NC}"
    
    if [[ "$SCOPE" == "system" ]]; then
        sudo mkdir -p /var/log/autoscheduler
        sudo chown $(whoami):staff /var/log/autoscheduler
        LOG_DIR="/var/log/autoscheduler"
    else
        mkdir -p "$HOME/Library/Logs/AutoScheduler"
        LOG_DIR="$HOME/Library/Logs/AutoScheduler"
    fi
    
    echo -e "${GREEN}✓ Log directory: $LOG_DIR${NC}"
}

# Install launchd service
install_launchd_service() {
    echo -e "${YELLOW}Installing launchd service...${NC}"
    
    if [[ "$SCOPE" == "system" ]]; then
        PLIST_DIR="/Library/LaunchDaemons"
        LOG_DIR="/var/log/autoscheduler"
        LABEL="com.autoscheduler.daemon"
        
        if [[ $EUID -ne 0 ]]; then
            echo -e "${RED}System installation requires sudo${NC}"
            exit 1
        fi
    else
        PLIST_DIR="$HOME/Library/LaunchAgents"
        LOG_DIR="$HOME/Library/Logs/AutoScheduler"
        LABEL="com.autoscheduler.daemon"
    fi
    
    # Create plist directory if needed
    mkdir -p "$PLIST_DIR"
    
    PLIST_PATH="$PLIST_DIR/$LABEL.plist"
    
    # Generate plist
    cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$(which julia)</string>
        <string>--project=$INSTALL_DIR</string>
        <string>-e</string>
        <string>using AutoScheduler; config = DaemonManager.DaemonConfig(rest_port=$REST_PORT, ws_port=$WS_PORT, log_file="$LOG_DIR/autoscheduler.log", pid_file="$LOG_DIR/autoscheduler.pid", monitor_interval=1.0, auto_optimize=false); DaemonManager.deploy_daemon(config)</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$LOG_DIR/stdout.log</string>
    
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/stderr.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>JULIA_NUM_THREADS</key>
        <string>$(sysctl -n hw.ncpu)</string>
        <key>JULIA_PROJECT</key>
        <string>$INSTALL_DIR</string>
    </dict>
    
    <key>ProcessType</key>
    <string>Interactive</string>
    
    <key>ThrottleInterval</key>
    <integer>10</integer>
    
    <key>ExitTimeOut</key>
    <integer>30</integer>
</dict>
</plist>
EOF

    # Set permissions
    chmod 644 "$PLIST_PATH"
    
    if [[ "$SCOPE" == "system" ]]; then
        sudo chown root:wheel "$PLIST_PATH"
    fi
    
    echo -e "${GREEN}✓ Plist created: $PLIST_PATH${NC}"
}

# Load and start service
start_service() {
    echo -e "${YELLOW}Starting service...${NC}"
    
    if [[ "$SCOPE" == "system" ]]; then
        PLIST_PATH="/Library/LaunchDaemons/com.autoscheduler.daemon.plist"
        sudo launchctl load -w "$PLIST_PATH"
    else
        PLIST_PATH="$HOME/Library/LaunchAgents/com.autoscheduler.daemon.plist"
        launchctl load -w "$PLIST_PATH"
    fi
    
    sleep 2
    
    # Check if service is running
    if launchctl list | grep -q "autoscheduler"; then
        echo -e "${GREEN}✓ Service started successfully${NC}"
    else
        echo -e "${RED}✗ Service failed to start${NC}"
        echo "Check logs: tail -f $LOG_DIR/stderr.log"
        exit 1
    fi
}

# Configure firewall (optional)
configure_firewall() {
    echo -e "${YELLOW}Firewall configuration...${NC}"
    
    # macOS firewall is typically managed via System Preferences
    # We'll just provide instructions
    echo -e "${YELLOW}If firewall is enabled, allow ports:${NC}"
    echo "  - TCP $REST_PORT (REST API)"
    echo "  - TCP $WS_PORT (WebSocket)"
    echo ""
    echo "Configure via: System Preferences > Security & Privacy > Firewall > Firewall Options"
}

# Run tests
run_tests() {
    echo -e "${YELLOW}Running tests...${NC}"
    
    cd "$INSTALL_DIR"
    julia --project=. test/runtests.jl || echo -e "${YELLOW}Tests had issues but continuing${NC}"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Installation Complete!                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Service Management:${NC}"
    
    if [[ "$SCOPE" == "system" ]]; then
        PLIST_PATH="/Library/LaunchDaemons/com.autoscheduler.daemon.plist"
        echo "  Load:     sudo launchctl load -w $PLIST_PATH"
        echo "  Unload:   sudo launchctl unload $PLIST_PATH"
        echo "  Status:   sudo launchctl list | grep autoscheduler"
    else
        PLIST_PATH="$HOME/Library/LaunchAgents/com.autoscheduler.daemon.plist"
        echo "  Load:     launchctl load -w $PLIST_PATH"
        echo "  Unload:   launchctl unload $PLIST_PATH"
        echo "  Status:   launchctl list | grep autoscheduler"
    fi
    
    echo ""
    echo -e "${GREEN}Logs:${NC}"
    
    if [[ "$SCOPE" == "system" ]]; then
        LOG_DIR="/var/log/autoscheduler"
    else
        LOG_DIR="$HOME/Library/Logs/AutoScheduler"
    fi
    
    echo "  Stdout:   tail -f $LOG_DIR/stdout.log"
    echo "  Stderr:   tail -f $LOG_DIR/stderr.log"
    echo ""
    echo -e "${GREEN}API Endpoints:${NC}"
    echo "  REST API:    http://localhost:$REST_PORT"
    echo "  Health:      http://localhost:$REST_PORT/api/v1/health"
    echo "  Metrics:     http://localhost:$REST_PORT/api/v1/metrics"
    echo "  WebSocket:   ws://localhost:$WS_PORT"
    echo "  Docs:        http://localhost:$REST_PORT/docs"
    echo ""
    echo -e "${GREEN}Installation Directory:${NC} $INSTALL_DIR"
    echo ""
    echo -e "${YELLOW}Test the service:${NC}"
    echo "  curl http://localhost:$REST_PORT/api/v1/health"
    echo ""
    
    # Apple Silicon specific notes
    if [[ "$ARCH" == "arm64" ]]; then
        echo -e "${BLUE}Apple Silicon Detected:${NC}"
        echo "  • Energy optimization is handled automatically by macOS"
        echo "  • Performance and Efficiency cores are managed by the OS"
        echo ""
    fi
}

# Main installation flow
main() {
    echo -e "${BLUE}Step 1/9: Installing Homebrew...${NC}"
    install_homebrew
    echo ""
    
    echo -e "${BLUE}Step 2/9: Installing Julia...${NC}"
    install_julia
    echo ""
    
    echo -e "${BLUE}Step 3/9: Installing dependencies...${NC}"
    install_dependencies
    echo ""
    
    echo -e "${BLUE}Step 4/9: Cloning repository...${NC}"
    clone_repository
    echo ""
    
    echo -e "${BLUE}Step 5/9: Installing Julia packages...${NC}"
    install_julia_deps
    echo ""
    
    echo -e "${BLUE}Step 6/9: Setting up directories...${NC}"
    setup_directories
    echo ""
    
    echo -e "${BLUE}Step 7/9: Installing launchd service...${NC}"
    install_launchd_service
    echo ""
    
    echo -e "${BLUE}Step 8/9: Starting service...${NC}"
    start_service
    echo ""
    
    echo -e "${BLUE}Step 9/9: Running tests...${NC}"
    run_tests
    echo ""
    
    configure_firewall
    
    print_summary
}

# Handle Ctrl+C
trap 'echo -e "\n${RED}Installation interrupted${NC}"; exit 1' INT

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --system)
            SCOPE="system"
            echo -e "${YELLOW}Installing as system daemon (requires sudo)${NC}"
            shift
            ;;
        --user)
            SCOPE="user"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--user|--system]"
            exit 1
            ;;
    esac
done

# Run main
main

exit 0