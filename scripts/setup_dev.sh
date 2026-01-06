#!/bin/bash
# scripts/setup_dev.sh
# Development environment setup for AutoScheduler.jl

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Setting up AutoScheduler.jl development environment..."
echo "Project root: $PROJECT_ROOT"
echo ""

# Check Julia installation
if ! command -v julia &> /dev/null; then
    echo "ERROR: Julia is not installed"
    echo "Please install Julia 1.10+ from https://julialang.org/downloads/"
    exit 1
fi

JULIA_VERSION=$(julia --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
echo "✓ Julia $JULIA_VERSION detected"

# Change to project directory
cd "$PROJECT_ROOT"

# Install Julia dependencies
echo ""
echo "Installing Julia dependencies..."
julia --project=. -e '
using Pkg
Pkg.instantiate()
Pkg.precompile()
println("\n✓ Dependencies installed")
'

# Setup git hooks
echo ""
echo "Setting up git hooks..."
mkdir -p .git/hooks

cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook: Run tests before commit

echo "Running tests before commit..."
julia --project=. test/runtests.jl

if [ $? -ne 0 ]; then
    echo "Tests failed! Commit aborted."
    exit 1
fi

echo "✓ Tests passed"
EOF

chmod +x .git/hooks/pre-commit
echo "✓ Git hooks installed"

# Create necessary directories
echo ""
echo "Creating directory structure..."
mkdir -p benchmarks/{data,results,scripts}
mkdir -p docs/build
mkdir -p test/{unit,integration,benchmarks}
mkdir -p examples
echo "✓ Directories created"

# Setup benchmark data
echo ""
echo "Setting up benchmark data..."
if [ -f "benchmarks/scripts/setup_data.sh" ]; then
    bash benchmarks/scripts/setup_data.sh
else
    echo "⚠ setup_data.sh not found, skipping"
fi

# Install development tools
echo ""
echo "Installing development tools..."
julia --project=. -e '
using Pkg
Pkg.add(["Revise", "BenchmarkTools", "ProfileView", "JET"])
println("✓ Development tools installed")
'

# Create .env file for local configuration
echo ""
echo "Creating .env file..."
cat > .env << 'EOF'
# AutoScheduler Development Configuration

# API settings
AUTOSCHEDULER_REST_PORT=8080
AUTOSCHEDULER_WS_PORT=8081

# Logging
AUTOSCHEDULER_LOG_LEVEL=INFO
AUTOSCHEDULER_LOG_FILE=autoscheduler.log

# Julia settings
JULIA_NUM_THREADS=auto

# Development mode
AUTOSCHEDULER_DEV_MODE=true
EOF
echo "✓ .env file created"

# Create startup.jl for development
echo ""
echo "Creating dev startup script..."
cat > dev_startup.jl << 'EOF'
# Load development environment
using Revise
using AutoScheduler

# Enable detailed logging
ENV["JULIA_DEBUG"] = "AutoScheduler"

println("AutoScheduler development environment loaded")
println("  - Revise.jl enabled (auto-reload on changes)")
println("  - AutoScheduler module imported")
println()
println("Quick start:")
println("  metrics = get_real_metrics()")
println("  gpus = get_gpu_info()")
println("  processes = get_running_processes()")
println()
EOF
echo "✓ Dev startup script created"

# Print success message
echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   Development Environment Setup Complete!  ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo "Project structure:"
echo "  src/          - Source code"
echo "  test/         - Test suite"
echo "  benchmarks/   - Benchmarks"
echo "  examples/     - Usage examples"
echo "  docs/         - Documentation"
echo ""
echo "Quick commands:"
echo "  Start development REPL:"
echo "    julia --project=. -i dev_startup.jl"
echo ""
echo "  Run tests:"
echo "    julia --project=. test/runtests.jl"
echo ""
echo "  Run specific test:"
echo "    julia --project=. test/unit/test_metrics.jl"
echo ""
echo "  Run benchmarks:"
echo "    julia --project=. benchmarks/run_all.jl"
echo ""
echo "  Start REST API server:"
echo "    julia --project=. -e 'using AutoScheduler; start_rest_server()'"
echo ""
echo "  Generate documentation:"
echo "    julia --project=docs docs/make.jl"
echo ""
echo "Development workflow:"
echo "  1. Edit source files in src/"
echo "  2. Revise.jl automatically reloads changes"
echo "  3. Test in REPL or run test suite"
echo "  4. Commit when tests pass"
echo ""
echo "Useful packages loaded:"
echo "  - Revise.jl:        Auto-reload code changes"
echo "  - BenchmarkTools:   Performance benchmarking"
echo "  - ProfileView:      Profile visualization"
echo "  - JET:              Static analysis"
echo ""
echo "Happy coding! 🚀"
echo ""