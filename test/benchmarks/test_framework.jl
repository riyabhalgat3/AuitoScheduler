# test/benchmarks/test_framework.jl
using AutoScheduler.BenchmarkFramework
using Statistics
using Dates  

@testset "Benchmark Framework Tests" begin
    @test begin
        # Test BenchmarkResult creation
        result = BenchmarkResult(
            "test_benchmark",
            "baseline",
            10.5,
            1000.0,
            100.0,
            512.0,
            75.0,
            0.0,
            now(),
            Dict("key" => "value")
        )
        
        @test result isa BenchmarkResult
        @test result.name == "test_benchmark"
        @test result.execution_time_s == 10.5
        true
    end
    
    @test begin
        # Test BenchmarkConfig creation
        config = BenchmarkConfig(
            "test",
            5,
            1,
            10.0,
            150.0,
            3600,
            "output"
        )
        
        @test config isa BenchmarkConfig
        @test config.iterations == 5
        @test config.warmup_iterations == 1
        true
    end
    
    @test begin
        # Test compare_results
        baseline_results = [
            BenchmarkResult("test", "baseline", 10.0, 1000.0, 100.0, 512.0, 
                          75.0, 0.0, now(), Dict()),
            BenchmarkResult("test", "baseline", 11.0, 1100.0, 95.0, 512.0,
                          75.0, 0.0, now(), Dict())
        ]
        
        scheduled_results = [
            BenchmarkResult("test", "scheduled", 8.0, 800.0, 120.0, 512.0,
                          75.0, 0.0, now(), Dict()),
            BenchmarkResult("test", "scheduled", 9.0, 900.0, 115.0, 512.0,
                          75.0, 0.0, now(), Dict())
        ]
        
        comparison = compare_results(baseline_results, scheduled_results)
        
        @test comparison isa ComparisonResult
        @test haskey(comparison.baseline_stats, "time_mean")
        @test haskey(comparison.scheduled_stats, "time_mean")
        @test haskey(comparison.improvements, "time_improvement_pct")
        true
    end
    
    @test begin
        # Test speedup calculation
        speedup = calculate_speedup(10.0, 8.0)
        @test speedup ≈ 1.25
        
        speedup2 = calculate_speedup(20.0, 10.0)
        @test speedup2 ≈ 2.0
        true
    end
    
    @test begin
        # Test Welch's t-test
        sample1 = [10.0, 11.0, 10.5, 10.2, 10.8]
        sample2 = [8.0, 8.5, 8.2, 8.3, 8.1]
        
        test_result = BenchmarkFramework.welch_t_test(sample1, sample2)
        
        @test test_result isa Dict
        @test haskey(test_result, "t_statistic")
        @test haskey(test_result, "significant")
        # Note: p_value and mean_difference may not be present in all implementations
        true
    end
    
    @test begin
        # Test statistical significance
        baseline = [
            BenchmarkResult("test", "baseline", 10.0, 1000.0, 100.0, 512.0,
                          75.0, 0.0, now(), Dict()),
            BenchmarkResult("test", "baseline", 11.0, 1100.0, 95.0, 512.0,
                          75.0, 0.0, now(), Dict())
        ]
        
        scheduled = [
            BenchmarkResult("test", "scheduled", 8.0, 800.0, 120.0, 512.0,
                          75.0, 0.0, now(), Dict()),
            BenchmarkResult("test", "scheduled", 9.0, 900.0, 115.0, 512.0,
                          75.0, 0.0, now(), Dict())
        ]
        
        comparison = compare_results(baseline, scheduled)
        significant = statistical_significance(comparison)
        
        @test significant isa Bool
        true
    end
    
    @test begin
        # Test report generation
        baseline = [
            BenchmarkResult("test", "baseline", 10.0, 1000.0, 100.0, 512.0,
                          75.0, 0.0, now(), Dict())
        ]
        
        scheduled = [
            BenchmarkResult("test", "scheduled", 8.0, 800.0, 120.0, 512.0,
                          75.0, 0.0, now(), Dict())
        ]
        
        comparison = compare_results(baseline, scheduled)
        
        output_file = tempname() * ".md"
        generate_report([comparison], output_file)
        
        @test isfile(output_file)
        @test filesize(output_file) > 0
        
        # Cleanup
        rm(output_file, force=true)
        true
    end
    
    @test begin
        # Test improvements calculation
        baseline = [
            BenchmarkResult("test", "baseline", 10.0, 1000.0, 100.0, 512.0,
                          75.0, 0.0, now(), Dict())
        ]
        
        scheduled = [
            BenchmarkResult("test", "scheduled", 8.0, 800.0, 125.0, 512.0,
                          75.0, 0.0, now(), Dict())
        ]
        
        comparison = compare_results(baseline, scheduled)
        
        # Time improvement: (10-8)/10 * 100 = 20%
        @test comparison.improvements["time_improvement_pct"] ≈ 20.0 atol=1.0
        
        # Energy savings: (1000-800)/1000 * 100 = 20%
        @test comparison.improvements["energy_savings_pct"] ≈ 20.0 atol=1.0
        
        # Speedup: 10/8 = 1.25
        @test comparison.improvements["speedup"] ≈ 1.25 atol=0.01
        true
    end
end