# test/unit/test_metrics.jl
@testset "Metrics Tests" begin
    @test begin
        metrics = get_real_metrics()
        metrics.total_cpu_usage >= 0 && metrics.total_cpu_usage <= 100
    end
    
    @test begin
        metrics = get_real_metrics()
        metrics.memory_total_bytes > 0
    end
    
    @test begin
        metrics = get_real_metrics()
        length(metrics.cpu_usage_per_core) == Sys.CPU_THREADS
    end
    
    @test begin
        metrics = get_real_metrics()
        metrics.memory_used_bytes >= 0
        metrics.memory_available_bytes >= 0
        metrics.memory_used_bytes <= metrics.memory_total_bytes
    end
    
    @test begin
        metrics = get_real_metrics()
        metrics.load_average_1min >= 0
        metrics.load_average_5min >= 0
        metrics.load_average_15min >= 0
    end
    
    @test begin
        metrics = get_real_metrics()
        metrics.process_count > 0
        metrics.thread_count > 0
    end
    
    @test begin
        metrics = get_real_metrics()
        metrics.platform in ["Linux", "Darwin", "FreeBSD", "Windows"]
    end
    
    @test begin
        # Test monitoring
        samples = monitor_system(5, interval=1.0)
        length(samples) >= 4  # Should get at least 4 samples in 5 seconds
    end
    
    @test begin
        # Test per-core usage
        metrics = get_real_metrics()
        for (core, usage) in metrics.cpu_usage_per_core
            @test usage >= 0 && usage <= 100
            @test core >= 0 && core < Sys.CPU_THREADS
        end
        true
    end
    
    @test begin
        # Test CPU frequency (if available)
        metrics = get_real_metrics()
        if !isempty(metrics.cpu_frequency_mhz)
            for (core, freq) in metrics.cpu_frequency_mhz
                @test freq > 0
                @test freq < 10000  # Reasonable upper bound
            end
        end
        true
    end
end