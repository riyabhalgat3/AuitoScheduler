# test/benchmarks/test_resnet.jl
using AutoScheduler.ResNetBenchmark

@testset "ResNet Benchmark Tests" begin
    @test begin
        # Test benchmark runs without scheduler
        config = ResNetConfig(
            batch_size=8,
            num_batches=5,
            image_size=224,
            num_classes=1000,
            use_gpu=false
        )
        
        result = run_resnet_benchmark(false, config)
        
        @test result isa Dict{String, Any}
        @test haskey(result, "throughput")
        @test haskey(result, "cpu_usage")
        @test result["throughput"] > 0
        true
    end
    
    @test begin
        # Test with scheduler
        config = ResNetConfig(
            batch_size=8,
            num_batches=5,
            use_gpu=false
        )
        
        result = run_resnet_benchmark(true, config)
        
        @test result isa Dict{String, Any}
        @test result["throughput"] > 0
        true
    end
    
    @test begin
        # Test configuration
        config = ResNetConfig(
            batch_size=16,
            num_batches=10,
            image_size=224,
            num_classes=1000,
            num_layers=50,
            use_gpu=false,
            mixed_precision=false
        )
        
        @test config.batch_size == 16
        @test config.num_batches == 10
        @test config.image_size == 224
        true
    end
    
    @test begin
        # Test estimation
        config = ResNetConfig(batch_size=32, num_batches=100)
        estimates = ResNetBenchmark.estimate_training_metrics(config)
        
        @test estimates isa Dict{String, Any}
        @test haskey(estimates, "estimated_time")
        @test haskey(estimates, "estimated_throughput")
        @test estimates["estimated_time"] > 0
        true
    end
    
    @test begin
        # Test memory estimation
        config = ResNetConfig(batch_size=32)
        memory = ResNetBenchmark.estimate_memory_usage(config)
        
        @test memory > 0
        @test memory < 100000  # Reasonable upper bound (MB)
        true
    end
    
    @test begin
        # Test with small batch for speed
        config = ResNetConfig(
            batch_size=4,
            num_batches=2,
            use_gpu=false
        )
        
        baseline_result = run_resnet_benchmark(false, config)
        scheduled_result = run_resnet_benchmark(true, config)
        
        @test baseline_result["throughput"] > 0
        @test scheduled_result["throughput"] > 0
        true
    end
end