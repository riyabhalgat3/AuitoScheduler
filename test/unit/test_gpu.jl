# test/unit/test_gpu.jl
@testset "GPU Tests" begin
    @test begin
        gpus = get_gpu_info()
        gpus isa Vector
    end
    
    @test begin
        gpus = get_gpu_info()
        all(g -> g.memory_total_bytes >= 0, gpus)
    end
    
    @test begin
        gpus = get_gpu_info()
        # Test GPU structure if GPUs are detected
        if !isempty(gpus)
            for gpu in gpus
                @test gpu.id >= 0
                @test !isempty(gpu.name)
                @test gpu.vendor in ["NVIDIA", "AMD", "Intel", "Apple", "Unknown"]
                @test gpu.memory_total_bytes >= 0
                @test gpu.memory_used_bytes >= 0
                @test gpu.memory_free_bytes >= 0
                @test gpu.utilization_percent >= 0 && gpu.utilization_percent <= 100
            end
        end
        true
    end
    
    @test begin
        # Test NVIDIA detection specifically (if available)
        gpus = get_gpu_info()
        nvidia_gpus = filter(g -> g.vendor == "NVIDIA", gpus)
        if !isempty(nvidia_gpus)
            for gpu in nvidia_gpus
                @test !isempty(gpu.driver_version)
                @test !isempty(gpu.compute_capability)
            end
        end
        true
    end
    
    @test begin
        # Test GPU monitoring (if GPU available)
        gpus = get_gpu_info()
        if !isempty(gpus)
            samples = monitor_gpu(0, duration=3, interval=1.0)
            @test length(samples) >= 2
            
            for sample in samples
                @test sample.utilization_percent >= 0
                @test sample.utilization_percent <= 100
            end
        end
        true
    end
    
    @test begin
        # Test Apple Silicon detection
        if Sys.isapple() && string(Sys.ARCH) != "x86_64"
            gpus = get_gpu_info()
            apple_gpus = filter(g -> g.vendor == "Apple", gpus)
            @test !isempty(apple_gpus)
        end
        true
    end
end