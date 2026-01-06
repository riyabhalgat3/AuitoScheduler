# test/benchmarks/test_monte_carlo.jl
using AutoScheduler.MonteCarloBenchmark

@testset "Monte Carlo Benchmark Tests" begin
    @test begin
        # Test benchmark runs
        config = MonteCarloConfig(
            n_samples=1_000_000,
            n_threads=4
        )
        
        result = run_monte_carlo_benchmark(false, config)
        
        @test result isa Dict{String, Any}
        @test haskey(result, "throughput")
        @test haskey(result, "pi_estimate")
        @test haskey(result, "error")
        true
    end
    
    @test begin
        # Test with scheduler
        config = MonteCarloConfig(
            n_samples=1_000_000,
            n_threads=4
        )
        
        result = run_monte_carlo_benchmark(true, config)
        
        @test result isa Dict{String, Any}
        @test result["throughput"] > 0
        true
    end
    
    @test begin
        # Test π estimation accuracy
        config = MonteCarloConfig(
            n_samples=10_000_000,
            n_threads=Sys.CPU_THREADS
        )
        
        result = run_monte_carlo_benchmark(false, config)
        
        @test haskey(result, "pi_estimate")
        @test haskey(result, "error")
        
        pi_estimate = result["pi_estimate"]
        error = result["error"]
        
        # Check if estimate is reasonable
        @test abs(pi_estimate - π) < 0.1
        @test error >= 0
        true
    end
    
    @test begin
        # Test configuration
        config = MonteCarloConfig(
            n_samples=5_000_000,
            n_threads=8
        )
        
        @test config.n_samples == 5_000_000
        @test config.n_threads == 8
        true
    end
    
    @test begin
        # Test throughput calculation
        config = MonteCarloConfig(n_samples=1_000_000)
        
        result = run_monte_carlo_benchmark(false, config)
        
        @test result["throughput"] > 0
        @test result["throughput"] < 1e12  # Sanity check
        true
    end
    
    @test begin
        # Compare baseline vs scheduled
        config = MonteCarloConfig(
            n_samples=5_000_000,
            n_threads=4
        )
        
        baseline = run_monte_carlo_benchmark(false, config)
        scheduled = run_monte_carlo_benchmark(true, config)
        
        @test baseline["throughput"] > 0
        @test scheduled["throughput"] > 0
        
        # Both should give reasonable π estimates
        @test abs(baseline["pi_estimate"] - π) < 0.1
        @test abs(scheduled["pi_estimate"] - π) < 0.1
        true
    end
    
    @test begin
        # Test with minimal samples for speed
        config = MonteCarloConfig(
            n_samples=100_000,
            n_threads=2
        )
        
        result = run_monte_carlo_benchmark(false, config)
        
        @test result["n_samples"] == 100_000
        @test result["cpu_usage"] >= 0
        true
    end
end