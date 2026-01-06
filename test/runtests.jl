# test/runtests.jl
using Test
using AutoScheduler

println("\n" * "="^80)
println("AutoScheduler Test Suite - Research Paper Validation")
println("="^80)
println("System: $(Sys.KERNEL) / $(Sys.ARCH)")
println("Julia Version: $(Base.VERSION)")
println("CPU Cores: $(Sys.CPU_THREADS)")
println("="^80 * "\n")

@testset "AutoScheduler Tests" begin
    # Core functionality tests
    @testset "Metrics Tests" begin
        include("unit/test_metrics.jl")
    end
    
    @testset "GPU Tests" begin
        include("unit/test_gpu.jl")
    end
    
    @testset "Scheduler Tests" begin
        include("unit/test_scheduler.jl")
    end
    
    @testset "DVFS Tests" begin
        include("unit/test_dvfs.jl")
    end
    
    @testset "HEFT Tests" begin
        include("unit/test_heft.jl")
    end
    
    # Integration tests (only working ones)
    @testset "Integration" begin
        @testset "Live Scheduler Tests" begin
            include("integration/test_live_scheduler.jl")
        end
    end
    
    # Benchmark tests
    @testset "Benchmarks" begin
        @testset "ResNet Benchmark Tests" begin
            include("benchmarks/test_resnet.jl")
        end
        
        @testset "Monte Carlo Benchmark Tests" begin
            include("benchmarks/test_monte_carlo.jl")
        end
        
        @testset "Benchmark Framework Tests" begin
            include("benchmarks/test_framework.jl")
        end
    end
end

println("\n" * "="^80)
println("Test Suite Complete")
println("="^80)
println("\nFor detailed demonstration, run:")
println("  julia --project=. demo_research.jl")
println("="^80 * "\n")