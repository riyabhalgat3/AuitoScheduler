# test/unit/test_scheduler.jl

# Use the Task type from AutoScheduler.SchedulerCore
const ASTask = AutoScheduler.SchedulerCore.Task

# Import schedule and ScheduleResult explicitly
using AutoScheduler: schedule, ScheduleResult

@testset "Scheduler Tests" begin
    @test begin
        tasks = [ASTask("t1", 1024, 50.0, :cpu_intensive, String[], nothing, 0.5)]
        result = schedule(tasks, verbose=false)
        result isa ScheduleResult
    end
    
    @test begin
        tasks = [
            ASTask("t1", 1024, 50.0, :cpu_intensive, String[], nothing, 0.5),
            ASTask("t2", 2048, 70.0, :cpu_intensive, ["t1"], nothing, 0.7)
        ]
        result = schedule(tasks, verbose=false)
        result.energy_savings_percent >= 0
    end
    
    @test begin
        # Test with different optimization targets
        tasks = [ASTask("t1", 1024, 50.0, :cpu_intensive, String[], nothing, 0.5)]
        
        energy_result = schedule(tasks, optimize_for=:energy, verbose=false)
        perf_result = schedule(tasks, optimize_for=:performance, verbose=false)
        balanced_result = schedule(tasks, optimize_for=:balanced, verbose=false)
        
        @test energy_result isa ScheduleResult
        @test perf_result isa ScheduleResult
        @test balanced_result isa ScheduleResult
        true
    end
    
    @test begin
        # Test with dependencies
        tasks = [
            ASTask("load", 1024, 30.0, :cpu_intensive, String[], nothing, 0.5),
            ASTask("process", 2048, 60.0, :cpu_intensive, ["load"], nothing, 0.7),
            ASTask("save", 512, 20.0, :io_intensive, ["process"], nothing, 0.4)
        ]
        result = schedule(tasks, verbose=false)
        @test result isa ScheduleResult
        true
    end
    
    @test begin
        # Test with deadlines
        tasks = [
            ASTask("urgent", 1024, 50.0, :cpu_intensive, String[], 10.0, 1.0),
            ASTask("normal", 2048, 70.0, :cpu_intensive, String[], 30.0, 0.5)
        ]
        result = schedule(tasks, verbose=false)
        @test result isa ScheduleResult
        true
    end
    
    @test begin
        # Test with power budget
        tasks = [ASTask("t1", 1024, 50.0, :cpu_intensive, String[], nothing, 0.5)]
        result = schedule(tasks, power_budget=80.0, verbose=false)
        @test result isa ScheduleResult
        true
    end
    
    @test begin
        # Test GPU-intensive task
        tasks = [ASTask("train", 8192, 90.0, :gpu_intensive, String[], nothing, 0.9)]
        result = schedule(tasks, verbose=false)
        @test result isa ScheduleResult
        true
    end
    
    @test begin
        # Test memory-intensive task
        tasks = [ASTask("big_data", 16384, 40.0, :memory_intensive, String[], nothing, 0.6)]
        result = schedule(tasks, verbose=false)
        @test result isa ScheduleResult
        true
    end
    
    @test begin
        # Test result fields
        tasks = [ASTask("t1", 1024, 50.0, :cpu_intensive, String[], nothing, 0.5)]
        result = schedule(tasks, verbose=false)
        
        @test hasfield(typeof(result), :allocation)
        @test hasfield(typeof(result), :energy_savings_percent)
        @test hasfield(typeof(result), :time_savings_percent)
        @test hasfield(typeof(result), :battery_extension_minutes)
        @test hasfield(typeof(result), :cost_savings_dollars)
        true
    end
end