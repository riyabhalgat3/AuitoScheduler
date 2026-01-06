#!/bin/sh
# AutoScheduler.jl - FreeBSD Installation Script
# Supports: FreeBSD 13+, x86_64 and ARM64
# PRODUCTION READY

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/autoscheduler"
SERVICE_USER="autoscheduler"
SERVICE_GROUP="autoscheduler"
JULIA_VERSION="1.10.0"
REST_PORT=8080
WS_PORT=8081

echo "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo "${BLUE}║   AutoScheduler.jl Installation Script    ║${NC}"
echo "${BLUE}║   FreeBSD 13+                              ║${NC}"
echo "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ $(id -u) -ne 0 ]; then
   echo "${RED}Error: This script must be run as root${NC}"
   echo "Usage: su root -c 'sh $0'"
   exit 1
fi

# Detect FreeBSD version
FREEBSD_VERSION=$(freebsd-version | cut -d'-' -f1)
ARCH=$(uname -m)

echo "${GREEN}Detected: FreeBSD $FREEBSD_VERSION${NC}"
echo "${GREEN}Architecture: $ARCH${NC}"
echo ""

# Update package repository
update_packages() {
    echo "${YELLOW}Updating package repository...${NC}"
    pkg update
    echo "${GREEN}✓ Package repository updated${NC}"
}

# Install Julia
install_julia() {
    echo "${YELLOW}Installing Julia...${NC}"
    
    if command -v julia >/dev/null 2>&1; then
        JULIA_CURRENT=$(julia --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo "${GREEN}Julia $JULIA_CURRENT already installed${NC}"
        return 0
    fi
    
    # Install Julia via pkg
    pkg install -y julia
    
    echo "${GREEN}✓ Julia installed${NC}"
    julia --version
}

# Install dependencies
install_dependencies() {
    echo "${YELLOW}Installing system dependencies...${NC}"
    
    pkg install -y \
        git \
        curl \
        wget \
        ca_root_nss \
        bash \
        gmake \
        gcc \
        llvm
    
    echo "${GREEN}✓ Dependencies installed${NC}"
}

# Create service user
create_service_user() {
    echo "${YELLOW}Creating service user...${NC}"
    
    if id "$SERVICE_USER" >/dev/null 2>&1; then
        echo "${GREEN}User $SERVICE_USER already exists${NC}"
    else
        pw useradd "$SERVICE_USER" -d /nonexistent -s /usr/sbin/nologin -c "AutoScheduler Service User"
        echo "${GREEN}✓ Created user: $SERVICE_USER${NC}"
    fi
}

# Clone repository
clone_repository() {
    echo "${YELLOW}Cloning AutoScheduler.jl repository...${NC}"
    
    if [ -d "$INSTALL_DIR" ]; then
        echo "${YELLOW}Directory exists, pulling latest changes...${NC}"
        cd "$INSTALL_DIR"
        git pull
    else
        git clone https://github.com/your-org/AutoScheduler.jl.git "$INSTALL_DIR"
    fi
    
    cd "$INSTALL_DIR"
    echo "${GREEN}✓ Repository ready${NC}"
}

# Install Julia dependencies
install_julia_deps() {
    echo "${YELLOW}Installing Julia dependencies...${NC}"
    
    cd "$INSTALL_DIR"
    
    # Instantiate project
    julia --project=. -e 'using Pkg; Pkg.instantiate()'
    
    # Precompile
    julia --project=. -e 'using Pkg; Pkg.precompile()'
    
    echo "${GREEN}✓ Julia dependencies installed${NC}"
}

# Setup directories and permissions
setup_directories() {
    echo "${YELLOW}Setting up directories...${NC}"
    
    # Create log directory
    mkdir -p /var/log/autoscheduler
    chown "$SERVICE_USER:$SERVICE_GROUP" /var/log/autoscheduler
    chmod 755 /var/log/autoscheduler
    
    # Create run directory
    mkdir -p /var/run/autoscheduler
    chown "$SERVICE_USER:$SERVICE_GROUP" /var/run/autoscheduler
    chmod 755 /var/run/autoscheduler
    
    # Set ownership of install directory
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"
    
    echo "${GREEN}✓ Directories configured${NC}"
}

# Install rc.d script
install_rc_script() {
    echo "${YELLOW}Installing rc.d service script...${NC}"
    
    cat > /usr/local/etc/rc.d/autoscheduler <<'EOF'
#!/bin/sh

# PROVIDE: autoscheduler
# REQUIRE: DAEMON NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="autoscheduler"
rcvar="autoscheduler_enable"

load_rc_config $name

: ${autoscheduler_enable:="NO"}
: ${autoscheduler_user:="autoscheduler"}
: ${autoscheduler_group:="autoscheduler"}
: ${autoscheduler_install_dir:="/usr/local/autoscheduler"}
: ${autoscheduler_rest_port:="8080"}
: ${autoscheduler_ws_port:="8081"}
: ${autoscheduler_log_file:="/var/log/autoscheduler/autoscheduler.log"}
: ${autoscheduler_pid_file:="/var/run/autoscheduler/autoscheduler.pid"}

pidfile="${autoscheduler_pid_file}"
command="/usr/local/bin/julia"
command_args="--project=${autoscheduler_install_dir} -e 'using AutoScheduler; config = DaemonManager.DaemonConfig(rest_port=${autoscheduler_rest_port}, ws_port=${autoscheduler_ws_port}, log_file=\"${autoscheduler_log_file}\", pid_file=\"${autoscheduler_pid_file}\", monitor_interval=1.0, auto_optimize=false); DaemonManager.deploy_daemon(config)'"

start_cmd="${name}_start"
stop_cmd="${name}_stop"

autoscheduler_start() {
    echo "Starting ${name}."
    
    export JULIA_NUM_THREADS=$(sysctl -n hw.ncpu)
    export JULIA_PROJECT="${autoscheduler_install_dir}"
    
    /usr/sbin/daemon -u ${autoscheduler_user} -p ${pidfile} \
        ${command} ${command_args}
}

autoscheduler_stop() {
    echo "Stopping ${name}."
    
    if [ -f ${pidfile} ]; then
        kill $(cat ${pidfile})
        rm -f ${pidfile}
    else
        echo "${name} not running?"
    fi
}

run_rc_command "$1"
EOF

    # Set permissions
    chmod 555 /usr/local/etc/rc.d/autoscheduler
    
    echo "${GREEN}✓ rc.d script installed${NC}"
}

# Configure service
configure_service() {
    echo "${YELLOW}Configuring service...${NC}"
    
    # Add to rc.conf
    sysrc autoscheduler_enable="YES"
    sysrc autoscheduler_user="$SERVICE_USER"
    sysrc autoscheduler_group="$SERVICE_GROUP"
    sysrc autoscheduler_install_dir="$INSTALL_DIR"
    sysrc autoscheduler_rest_port="$REST_PORT"
    sysrc autoscheduler_ws_port="$WS_PORT"
    
    echo "${GREEN}✓ Service configured${NC}"
}

# Configure firewall (optional)
configure_firewall() {
    echo "${YELLOW}Firewall configuration...${NC}"
    
    # Check if ipfw is enabled
    if sysrc -n firewall_enable 2>/dev/null | grep -q "YES"; then
        echo "${YELLOW}IPFW firewall detected${NC}"
        echo "Add these rules to /etc/ipfw.rules:"
        echo "  ipfw add allow tcp from any to me $REST_PORT in"
        echo "  ipfw add allow tcp from any to me $WS_PORT in"
    fi
    
    # Check if pf is enabled
    if sysrc -n pf_enable 2>/dev/null | grep -q "YES"; then
        echo "${YELLOW}PF firewall detected${NC}"
        echo "Add these rules to /etc/pf.conf:"
        echo "  pass in proto tcp to port $REST_PORT"
        echo "  pass in proto tcp to port $WS_PORT"
    fi
}

# Start service
start_service() {
    echo "${YELLOW}Starting service...${NC}"
    
    service autoscheduler start
    
    sleep 2
    
    if service autoscheduler status >/dev/null 2>&1; then
        echo "${GREEN}✓ Service started successfully${NC}"
    else
        echo "${RED}✗ Service failed to start${NC}"
        echo "Check logs: tail -f /var/log/autoscheduler/autoscheduler.log"
        exit 1
    fi
}

# Run tests
run_tests() {
    echo "${YELLOW}Running tests...${NC}"
    
    cd "$INSTALL_DIR"
    julia --project=. test/runtests.jl || echo "${YELLOW}Tests had issues but continuing${NC}"
}

# Print summary
print_summary() {
    echo ""
    echo "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo "${BLUE}║   Installation Complete!                  ║${NC}"
    echo "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo "${GREEN}Service Management:${NC}"
    echo "  Start:    service autoscheduler start"
    echo "  Stop:     service autoscheduler stop"
    echo "  Restart:  service autoscheduler restart"
    echo "  Status:   service autoscheduler status"
    echo "  Enable:   sysrc autoscheduler_enable=YES"
    echo "  Disable:  sysrc autoscheduler_enable=NO"
    echo ""
    echo "${GREEN}Logs:${NC}"
    echo "  Main log: tail -f /var/log/autoscheduler/autoscheduler.log"
    echo ""
    echo "${GREEN}API Endpoints:${NC}"
    echo "  REST API:    http://localhost:$REST_PORT"
    echo "  Health:      http://localhost:$REST_PORT/api/v1/health"
    echo "  Metrics:     http://localhost:$REST_PORT/api/v1/metrics"
    echo "  WebSocket:   ws://localhost:$WS_PORT"
    echo "  Docs:        http://localhost:$REST_PORT/docs"
    echo ""
    echo "${GREEN}Installation Directory:${NC} $INSTALL_DIR"
    echo ""
    echo "${YELLOW}Test the service:${NC}"
    echo "  fetch -o - http://localhost:$REST_PORT/api/v1/health"
    echo ""
}

# Main installation flow
main() {
    echo "${BLUE}Step 1/10: Updating packages...${NC}"
    update_packages
    echo ""
    
    echo "${BLUE}Step 2/10: Installing Julia...${NC}"
    install_julia
    echo ""
    
    echo "${BLUE}Step 3/10: Installing dependencies...${NC}"
    install_dependencies
    echo ""
    
    echo "${BLUE}Step 4/10: Creating service user...${NC}"
    create_service_user
    echo ""
    
    echo "${BLUE}Step 5/10: Cloning repository...${NC}"
    clone_repository
    echo ""
    
    echo "${BLUE}Step 6/10: Installing Julia packages...${NC}"
    install_julia_deps
    echo ""
    
    echo "${BLUE}Step 7/10: Setting up directories...${NC}"
    setup_directories
    echo ""
    
    echo "${BLUE}Step 8/10: Installing rc.d script...${NC}"
    install_rc_script
    configure_service
    echo ""
    
    echo "${BLUE}Step 9/10: Starting service...${NC}"
    start_service
    echo ""
    
    echo "${BLUE}Step 10/10: Running tests...${NC}"
    run_tests
    echo ""
    
    configure_firewall
    
    print_summary
}

# Handle Ctrl+C
trap 'echo "\n${RED}Installation interrupted${NC}"; exit 1' INT

# Run main
main

exit 0