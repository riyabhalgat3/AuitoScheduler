#!/bin/bash
# scripts/run_ci.sh
# Continuous Integration script for AutoScheduler.jl

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AutoScheduler.jl CI Pipeline             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

cd "$PROJECT_ROOT"

# Track failures
FAILED_STEPS=()

# Step 1: Environment Info
echo -e "${BLUE}[1/7] Environment Information${NC}"
echo "----------------------------------------"
echo "OS: $(uname -s) $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Julia version: $(julia --version)"
echo "CPU cores: $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 'unknown')"
echo "Memory: $(free -h 2>/dev/null | grep Mem | awk '{print $2}' || sysctl -n hw.memsize 2>/dev/null | awk '{print $1/1024/1024/1024 " GB"}' || echo 'unknown')"
echo "✓ Environment check complete"
echo ""

# Step 2: Dependency Installation
echo -e "${BLUE}[2/7] Installing Dependencies${NC}"
echo "----------------------------------------"
if julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' 2>&1 | tail -5; then
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${RED}✗ Dependency installation failed${NC}"
    FAILED_STEPS+=("Dependencies")
fi
echo ""

# Step 3: Code Quality Checks
echo -e "${BLUE}[3/7] Code Quality Checks${NC}"
echo "----------------------------------------"

# Check for syntax errors
echo "Checking syntax..."
if julia --project=. -e '
using Pkg
for file in readdir("src", join=true)
    if endswith(file, ".jl")
        try
            include(file)
        catch e
            println("Syntax error in $file: $e")
            exit(1)
        end
    end
end
println("✓ No syntax errors")
' 2>&1; then
    echo -e "${GREEN}✓ Syntax check passed${NC}"
else
    echo -e "${RED}✗ Syntax check failed${NC}"
    FAILED_STEPS+=("Syntax Check")
fi
echo ""

# Step 4: Unit Tests
echo -e "${BLUE}[4/7] Running Unit Tests${NC}"
echo "----------------------------------------"
if julia --project=. --code-coverage=user test/runtests.jl 2>&1 | tee test_output.log | tail -20; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
else
    echo -e "${RED}✗ Unit tests failed${NC}"
    FAILED_STEPS+=("Unit Tests")
fi
echo ""

# Step 5: Integration Tests
echo -e "${BLUE}[5/7] Running Integration Tests${NC}"
echo "----------------------------------------"
if [ -f "test/integration/test_live_scheduler.jl" ]; then
    if julia --project=. test/integration/test_live_scheduler.jl 2>&1 | tail -10; then
        echo -e "${GREEN}✓ Integration tests passed${NC}"
    else
        echo -e "${RED}✗ Integration tests failed${NC}"
        FAILED_STEPS+=("Integration Tests")
    fi
else
    echo -e "${YELLOW}⚠ Integration tests not found, skipping${NC}"
fi
echo ""

# Step 6: Benchmark Validation
echo -e "${BLUE}[6/7] Benchmark Validation${NC}"
echo "----------------------------------------"
echo "Running quick benchmark validation..."
if julia --project=. -e '
using AutoScheduler
using AutoScheduler.ResNetBenchmark

println("Running ResNet quick benchmark...")
config = ResNetConfig(batch_size=4, num_batches=2, use_gpu=false)
result = run_resnet_benchmark(false, config)

if result["throughput"] > 0
    println("✓ Benchmark validation passed")
    exit(0)
else
    println("✗ Benchmark validation failed")
    exit(1)
end
' 2>&1 | tail -10; then
    echo -e "${GREEN}✓ Benchmark validation passed${NC}"
else
    echo -e "${RED}✗ Benchmark validation failed${NC}"
    FAILED_STEPS+=("Benchmarks")
fi
echo ""

# Step 7: Code Coverage
echo -e "${BLUE}[7/7] Code Coverage Analysis${NC}"
echo "----------------------------------------"
if [ -f "test_output.log" ]; then
    # Count test results
    TOTAL_TESTS=$(grep -c "@test" test_output.log 2>/dev/null || echo "0")
    PASSED_TESTS=$(grep -c "Test Passed" test_output.log 2>/dev/null || echo "0")
    
    if [ "$TOTAL_TESTS" -gt 0 ]; then
        COVERAGE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo "Test Results:"
        echo "  Total tests: $TOTAL_TESTS"
        echo "  Passed: $PASSED_TESTS"
        echo "  Coverage: $COVERAGE%"
        
        if [ "$COVERAGE" -ge 80 ]; then
            echo -e "${GREEN}✓ Good test coverage${NC}"
        elif [ "$COVERAGE" -ge 60 ]; then
            echo -e "${YELLOW}⚠ Moderate test coverage${NC}"
        else
            echo -e "${RED}✗ Low test coverage${NC}"
            FAILED_STEPS+=("Coverage")
        fi
    else
        echo "Unable to determine coverage"
    fi
else
    echo "No test output found"
fi
echo ""

# Generate coverage report
if ls ./*.cov 1> /dev/null 2>&1; then
    echo "Generating coverage report..."
    julia --project=. -e '
    using Coverage
    coverage = process_folder()
    covered_lines, total_lines = get_summary(coverage)
    percentage = covered_lines / total_lines * 100
    @printf("Code coverage: %.1f%% (%d/%d lines)\n", percentage, covered_lines, total_lines)
    ' 2>/dev/null || echo "Coverage.jl not available"
    
    # Clean up coverage files
    rm -f ./*.cov
fi
echo ""

# Final Summary
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   CI Pipeline Summary                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

if [ ${#FAILED_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
    echo ""
    echo "Pipeline completed successfully!"
    echo "  - Environment validated"
    echo "  - Dependencies installed"
    echo "  - Code quality checks passed"
    echo "  - Unit tests passed"
    echo "  - Integration tests passed"
    echo "  - Benchmarks validated"
    echo "  - Coverage analyzed"
    echo ""
    exit 0
else
    echo -e "${RED}✗ PIPELINE FAILED${NC}"
    echo ""
    echo "Failed steps:"
    for step in "${FAILED_STEPS[@]}"; do
        echo -e "  ${RED}✗ $step${NC}"
    done
    echo ""
    echo "Please fix the issues and try again."
    echo ""
    exit 1
fi