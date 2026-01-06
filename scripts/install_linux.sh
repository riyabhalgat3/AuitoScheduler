#!/bin/bash
# AutoScheduler.jl - Linux Installation Script
# Supports: Ubuntu, Debian, Fedora, RHEL, CentOS, Arch, openSUSE
# PRODUCTION READY

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/autoscheduler"
SERVICE_USER="autoscheduler"
SERVICE_GROUP="autoscheduler"
JULIA_VERSION="1.10.0"
REST_PORT=8080
WS_PORT=8081

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AutoScheduler.jl Installation Script    ║${NC}"
echo -e "${BLUE}║   Linux (Universal)                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Usage: sudo $0"
   exit 1
fi

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
    else
        DISTRO=$(uname -s)
        VERSION=$(uname -r)
    fi
    
    echo -e "${GREEN}Detected: $DISTRO $VERSION${NC}"
}

# Install Julia
install_julia() {
    echo -e "${YELLOW}Installing Julia...${NC}"
    
    if command -v julia &> /dev/null; then
        JULIA_CURRENT=$(julia --version | grep -oP '\d+\.\d+\.\d+')
        echo -e "${GREEN}Julia $JULIA_CURRENT already installed${NC}"
        return 0
    fi
    
    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y wget curl tar gzip
            ;;
        fedora|rhel|centos|rocky|almalinux)
            dnf install -y wget curl tar gzip || yum install -y wget curl tar gzip
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm wget curl tar gzip
            ;;
        opensuse*)
            zypper install -y wget curl tar gzip
            ;;
    esac
    
    # Download Julia
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-${JULIA_VERSION}-linux-x86_64.tar.gz"
    elif [ "$ARCH" = "aarch64" ]; then
        JULIA_URL="https://julialang-s3.julialang.org/bin/linux/aarch64/1.10/julia-${JULIA_VERSION}-linux-aarch64.tar.gz"
    else
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
    fi
    
    cd /tmp
    wget -q --show-progress "$JULIA_URL" -O julia.tar.gz
    tar -xzf julia.tar.gz
    
    # Install to /opt
    mv julia-${JULIA_VERSION} /opt/julia
    ln -sf /opt/julia/bin/julia /usr/local/bin/julia
    
    rm julia.tar.gz
    
    echo -e "${GREEN}✓ Julia installed${NC}"
    julia --version
}

# Install system dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    
    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                build-essential \
                git \
                curl \
                wget \
                ca-certificates \
                lm-sensors \
                sysstat \
                procps
            ;;
        fedora|rhel|centos|rocky|almalinux)
            dnf install -y \
                gcc \
                gcc-c++ \
                make \
                git \
                curl \
                wget \
                ca-certificates \
                lm_sensors \
                sysstat \
                procps-ng || \
            yum install -y \
                gcc \
                gcc-c++ \
                make \
                git \
                curl \
                wget \
                ca-certificates \
                lm_sensors \
                sysstat \
                procps-ng
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm \
                base-devel \
                git \
                curl \
                wget \
                ca-certificates \
                lm_sensors \
                sysstat \
                procps-ng
            ;;
        opensuse*)
            zypper install -y \
                gcc \
                gcc-c++ \
                make \
                git \
                curl \
                wget \
                ca-certificates \
                sensors \
                sysstat \
                procps
            ;;
    esac
    
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# Create service user
create_service_user() {
    echo -e "${YELLOW}Creating service user...${NC}"
    
    if id "$SERVICE_USER" &>/dev/null; then
        echo -e "${GREEN}User $SERVICE_USER already exists${NC}"
    else
        useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
        echo -e "${GREEN}✓ Created user: $SERVICE_USER${NC}"
    fi
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

# Setup directories and permissions
setup_directories() {
    echo -e "${YELLOW}Setting up directories...${NC}"
    
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
    
    echo -e "${GREEN}✓ Directories configured${NC}"
}

# Install systemd service
install_systemd_service() {
    echo -e "${YELLOW}Installing systemd service...${NC}"
    
    cat > /etc/systemd/system/autoscheduler.service <<EOF
[Unit]
Description=AutoScheduler - Energy-Aware Task Scheduling Service
Documentation=https://github.com/your-org/AutoScheduler.jl
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$INSTALL_DIR

Environment="JULIA_NUM_THREADS=$(nproc)"
Environment="JULIA_PROJECT=$INSTALL_DIR"

ExecStart=/usr/local/bin/julia --project=$INSTALL_DIR -e 'using AutoScheduler; config = DaemonManager.DaemonConfig(rest_port=$REST_PORT, ws_port=$WS_PORT, log_file="/var/log/autoscheduler/autoscheduler.log", pid_file="/var/run/autoscheduler/autoscheduler.pid", monitor_interval=1.0, auto_optimize=false); DaemonManager.deploy_daemon(config)'

Restart=on-failure
RestartSec=10s

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/autoscheduler /var/run/autoscheduler

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=autoscheduler

TimeoutStartSec=60s
TimeoutStopSec=30s
KillMode=mixed
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Systemd service installed${NC}"
}

# Configure firewall (optional)
configure_firewall() {
    echo -e "${YELLOW}Configuring firewall (optional)...${NC}"
    
    if command -v ufw &> /dev/null; then
        ufw allow $REST_PORT/tcp comment "AutoScheduler REST API"
        ufw allow $WS_PORT/tcp comment "AutoScheduler WebSocket"
        echo -e "${GREEN}✓ UFW rules added${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$REST_PORT/tcp
        firewall-cmd --permanent --add-port=$WS_PORT/tcp
        firewall-cmd --reload
        echo -e "${GREEN}✓ Firewalld rules added${NC}"
    else
        echo -e "${YELLOW}No firewall detected, skipping${NC}"
    fi
}

# Enable and start service
start_service() {
    echo -e "${YELLOW}Starting service...${NC}"
    
    systemctl enable autoscheduler
    systemctl start autoscheduler
    
    sleep 2
    
    if systemctl is-active --quiet autoscheduler; then
        echo -e "${GREEN}✓ Service started successfully${NC}"
    else
        echo -e "${RED}✗ Service failed to start${NC}"
        echo "Check logs: journalctl -u autoscheduler -n 50"
        exit 1
    fi
}

# Run tests
run_tests() {
    echo -e "${YELLOW}Running tests...${NC}"
    
    cd "$INSTALL_DIR"
    julia --project=. test/runtests.jl
    
    echo -e "${GREEN}✓ Tests passed${NC}"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Installation Complete!                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Service Management:${NC}"
    echo "  Start:    sudo systemctl start autoscheduler"
    echo "  Stop:     sudo systemctl stop autoscheduler"
    echo "  Restart:  sudo systemctl restart autoscheduler"
    echo "  Status:   sudo systemctl status autoscheduler"
    echo "  Logs:     sudo journalctl -u autoscheduler -f"
    echo ""
    echo -e "${GREEN}API Endpoints:${NC}"
    echo "  REST API:    http://localhost:$REST_PORT"
    echo "  Health:      http://localhost:$REST_PORT/api/v1/health"
    echo "  Metrics:     http://localhost:$REST_PORT/api/v1/metrics"
    echo "  WebSocket:   ws://localhost:$WS_PORT"
    echo "  Docs:        http://localhost:$REST_PORT/docs"
    echo ""
    echo -e "${GREEN}Installation Directory:${NC} $INSTALL_DIR"
    echo -e "${GREEN}Log Directory:${NC} /var/log/autoscheduler"
    echo ""
    echo -e "${YELLOW}Test the service:${NC}"
    echo "  curl http://localhost:$REST_PORT/api/v1/health"
    echo ""
}

# Main installation flow
main() {
    detect_distro
    echo ""
    
    echo -e "${BLUE}Step 1/10: Installing Julia...${NC}"
    install_julia
    echo ""
    
    echo -e "${BLUE}Step 2/10: Installing dependencies...${NC}"
    install_dependencies
    echo ""
    
    echo -e "${BLUE}Step 3/10: Creating service user...${NC}"
    create_service_user
    echo ""
    
    echo -e "${BLUE}Step 4/10: Cloning repository...${NC}"
    clone_repository
    echo ""
    
    echo -e "${BLUE}Step 5/10: Installing Julia packages...${NC}"
    install_julia_deps
    echo ""
    
    echo -e "${BLUE}Step 6/10: Setting up directories...${NC}"
    setup_directories
    echo ""
    
    echo -e "${BLUE}Step 7/10: Installing systemd service...${NC}"
    install_systemd_service
    echo ""
    
    echo -e "${BLUE}Step 8/10: Configuring firewall...${NC}"
    configure_firewall
    echo ""
    
    echo -e "${BLUE}Step 9/10: Starting service...${NC}"
    start_service
    echo ""
    
    echo -e "${BLUE}Step 10/10: Running tests...${NC}"
    run_tests || echo -e "${YELLOW}Tests failed but service is running${NC}"
    echo ""
    
    print_summary
}

# Handle Ctrl+C
trap 'echo -e "\n${RED}Installation interrupted${NC}"; exit 1' INT

# Run main
main

exit 0