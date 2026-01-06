# test/unit/test_heft.jl
using AutoScheduler.HEFT

@testset "HEFT Tests" begin
    @test begin
        task_graph = Dict("t1" => String[], "t2" => ["t1"])
        profiles = Dict(
            "t1" => HEFT.TaskExecutionProfile("t1", 
                Dict(HEFT.CPU_CORE => 1.0), 1024, 100, 0.5),
            "t2" => HEFT.TaskExecutionProfile("t2",
                Dict(HEFT.CPU_CORE => 2.0), 2048, 200, 0.7)
        )
        resources = [HEFT.Resource(1, HEFT.CPU_CORE, 1.0, 100.0, 0.0, 
                                    8*1024*1024*1024, 0, 50.0)]
        
        result = HEFT.heft_schedule(task_graph, profiles, resources)
        result.makespan > 0
    end
    
    @test begin
        # Test with multiple resources
        task_graph = Dict(
            "t1" => String[],
            "t2" => ["t1"],
            "t3" => ["t1"]
        )
        
        profiles = Dict(
            "t1" => HEFT.TaskExecutionProfile("t1", 
                Dict(HEFT.CPU_CORE => 2.0, HEFT.GPU_DEVICE => 1.0), 
                1024, 100, 0.5),
            "t2" => HEFT.TaskExecutionProfile("t2",
                Dict(HEFT.CPU_CORE => 3.0), 2048, 200, 0.7),
            "t3" => HEFT.TaskExecutionProfile("t3",
                Dict(HEFT.GPU_DEVICE => 1.5), 2048, 150, 0.6)
        )
        
        resources = [
            HEFT.Resource(1, HEFT.CPU_CORE, 1.0, 100.0, 0.0, 
                         8*1024*1024*1024, 0, 50.0),
            HEFT.Resource(2, HEFT.GPU_DEVICE, 2.0, 500.0, 0.0,
                         8*1024*1024*1024, 0, 150.0)
        ]
        
        result = HEFT.heft_schedule(task_graph, profiles, resources)
        
        @test result isa HEFT.ScheduleResult
        @test result.makespan > 0
        @test length(result.scheduled_tasks) == 3
        true
    end
    
    @test begin
        # Test validation
        task_graph = Dict("t1" => String[], "t2" => ["t1"])
        profiles = Dict(
            "t1" => HEFT.TaskExecutionProfile("t1", 
                Dict(HEFT.CPU_CORE => 1.0), 1024, 100, 0.5),
            "t2" => HEFT.TaskExecutionProfile("t2",
                Dict(HEFT.CPU_CORE => 2.0), 2048, 200, 0.7)
        )
        resources = [HEFT.Resource(1, HEFT.CPU_CORE, 1.0, 100.0, 0.0, 
                                    8*1024*1024*1024, 0, 50.0)]
        
        result = HEFT.heft_schedule(task_graph, profiles, resources)
        
        @test HEFT.validate_schedule(result.scheduled_tasks, task_graph)
        true
    end
    
    @test begin
        # Test makespan calculation
        task_graph = Dict("t1" => String[])
        profiles = Dict(
            "t1" => HEFT.TaskExecutionProfile("t1", 
                Dict(HEFT.CPU_CORE => 5.0), 1024, 100, 0.5)
        )
        resources = [HEFT.Resource(1, HEFT.CPU_CORE, 1.0, 100.0, 0.0, 
                                    8*1024*1024*1024, 0, 50.0)]
        
        result = HEFT.heft_schedule(task_graph, profiles, resources)
        makespan = HEFT.calculate_makespan(result.scheduled_tasks)
        
        @test makespan ≈ result.makespan
        @test makespan >= 5.0  # At least the execution time
        true
    end
    
    @test begin
        # Test resource utilization
        task_graph = Dict("t1" => String[], "t2" => ["t1"])
        profiles = Dict(
            "t1" => HEFT.TaskExecutionProfile("t1", 
                Dict(HEFT.CPU_CORE => 2.0), 1024, 100, 0.5),
            "t2" => HEFT.TaskExecutionProfile("t2",
                Dict(HEFT.CPU_CORE => 3.0), 2048, 200, 0.7)
        )
        resources = [HEFT.Resource(1, HEFT.CPU_CORE, 1.0, 100.0, 0.0, 
                                    8*1024*1024*1024, 0, 50.0)]
        
        result = HEFT.heft_schedule(task_graph, profiles, resources)
        
        @test haskey(result.resource_utilization, 1)
        @test result.resource_utilization[1] >= 0
        @test result.resource_utilization[1] <= 100
        true
    end
    
    @test begin
        # Test energy calculation
        task_graph = Dict("t1" => String[])
        profiles = Dict(
            "t1" => HEFT.TaskExecutionProfile("t1", 
                Dict(HEFT.CPU_CORE => 5.0), 1024, 100, 0.5)
        )
        resources = [HEFT.Resource(1, HEFT.CPU_CORE, 1.0, 100.0, 0.0, 
                                    8*1024*1024*1024, 0, 50.0)]
        
        result = HEFT.heft_schedule(task_graph, profiles, resources)
        
        @test result.total_energy > 0
        true
    end
    
    @test begin
        # Test critical path
        task_graph = Dict(
            "t1" => String[],
            "t2" => ["t1"],
            "t3" => ["t2"]
        )
        profiles = Dict(
            "t1" => HEFT.TaskExecutionProfile("t1", 
                Dict(HEFT.CPU_CORE => 2.0), 1024, 100, 0.5),
            "t2" => HEFT.TaskExecutionProfile("t2",
                Dict(HEFT.CPU_CORE => 3.0), 2048, 200, 0.7),
            "t3" => HEFT.TaskExecutionProfile("t3",
                Dict(HEFT.CPU_CORE => 1.0), 1024, 100, 0.6)
        )
        resources = [HEFT.Resource(1, HEFT.CPU_CORE, 1.0, 100.0, 0.0, 
                                    8*1024*1024*1024, 0, 50.0)]
        
        result = HEFT.heft_schedule(task_graph, profiles, resources)
        
        @test !isempty(result.critical_path)
        @test "t1" in result.critical_path
        @test "t3" in result.critical_path
        true
    end
end