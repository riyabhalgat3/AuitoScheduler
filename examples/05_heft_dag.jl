# examples/05_heft_dag.jl
using AutoScheduler
using AutoScheduler.HEFT
using Printf

println("HEFT DAG Scheduling Example\n")

# Define task graph (dependencies)
task_graph = Dict(
    "task1" => String[],
    "task2" => ["task1"],
    "task3" => ["task1"],
    "task4" => ["task2", "task3"]
)

# Define task execution profiles
profiles = Dict(
    "task1" => TaskExecutionProfile("task1", 
        Dict(CPU_CORE => 5.0, GPU_DEVICE => 2.0), 
        1024*1024*1024, 100*1024*1024, 0.5),
    "task2" => TaskExecutionProfile("task2",
        Dict(CPU_CORE => 3.0, GPU_DEVICE => 1.0),
        512*1024*1024, 50*1024*1024, 0.7),
    "task3" => TaskExecutionProfile("task3",
        Dict(CPU_CORE => 4.0), 
        768*1024*1024, 75*1024*1024, 0.6),
    "task4" => TaskExecutionProfile("task4",
        Dict(CPU_CORE => 6.0, GPU_DEVICE => 2.5),
        2048*1024*1024, 150*1024*1024, 0.8)
)

# Define resources
resources = [
    Resource(1, CPU_CORE, 1.0, 100.0, 0.0, 8*1024*1024*1024, 0, 50.0),
    Resource(2, GPU_DEVICE, 2.0, 500.0, 0.0, 8*1024*1024*1024, 0, 150.0)
]

# Schedule with HEFT
result = heft_schedule(task_graph, profiles, resources)

println("HEFT Schedule:")
@printf("  Makespan: %.2f seconds\n", result.makespan)
@printf("  Total Energy: %.2f J\n", result.total_energy)
println("\n  Schedule:")
for st in result.scheduled_tasks
    @printf("    %s on Resource %d: %.2f - %.2f s\n",
            st.task_id, st.resource_id, st.start_time, st.finish_time)
end
