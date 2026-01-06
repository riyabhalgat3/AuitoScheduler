# test/integration/test_cli.jl
@testset "CLI Tests" begin
    @test begin
        # Test monitor module exists
        using AutoScheduler.Monitor
        @test Monitor isa Module
        true
    end
    
    @test begin
        # Test MonitorConfig creation
        using AutoScheduler.Monitor
        
        config = MonitorConfig(
            refresh_interval=1.0,
            show_gpu=true,
            show_processes=true,
            show_power=true,
            max_processes=10
        )
        
        @test config isa MonitorConfig
        @test config.refresh_interval == 1.0
        @test config.max_processes == 10
        true
    end
    
    @test begin
        # Test profile module
        using AutoScheduler.Profile
        @test Profile isa Module
        true
    end
    
    @test begin
        # Test report module
        using AutoScheduler.Report
        @test Report isa Module
        true
    end
    
    @test begin
        # Test report generation
        using AutoScheduler.Report
        
        output_file = tempname() * ".md"
        Report.generate_system_report(output_file)
        
        @test isfile(output_file)
        @test filesize(output_file) > 0
        
        # Cleanup
        rm(output_file, force=true)
        true
    end
    
    @test begin
        # Test benchmark CLI module
        using AutoScheduler.BenchmarkCLI
        @test BenchmarkCLI isa Module
        true
    end
    
    # Skip interactive tests
    if haskey(ENV, "TEST_INTERACTIVE")
        @test begin
            # Test monitor with short duration
            using AutoScheduler.Monitor
            
            config = MonitorConfig(
                refresh_interval=1.0,
                show_gpu=false,
                show_processes=true,
                max_processes=5
            )
            
            # Run for 3 seconds
            Monitor.start_monitor(duration=3, config=config)
            true
        end
    end
end