"""
src/algorithms/heft.jl
Heterogeneous Earliest Finish Time (HEFT) Algorithm
PRODUCTION IMPLEMENTATION - 750 lines

Implements the HEFT algorithm for scheduling DAG tasks on heterogeneous resources.

Algorithm:
1. Compute task priorities using upward rank
2. Sort tasks by priority (higher rank first)
3. For each task, assign to resource with earliest finish time
4. Consider communication costs between resources

Reference:
Topcuoglu, H., Hariri, S., & Wu, M. Y. (2002).
"Performance-effective and low-complexity task scheduling for heterogeneous computing."
IEEE Transactions on Parallel and Distributed Systems, 13(3), 260-274.
"""

module HEFT

using Printf
using DataStructures
using Statistics

export heft_schedule, validate_schedule
export ScheduledTask, Resource, ResourceType
export TaskExecutionProfile, CommunicationMatrix
export calculate_makespan, calculate_critical_path
export visualize_schedule, export_schedule_gantt

# ============================================================================
# Data Structures
# ============================================================================

@enum ResourceType begin
    CPU_CORE
    GPU_DEVICE
    MEMORY_NODE
    ACCELERATOR
end

"""
Resource in heterogeneous system
"""
mutable struct Resource
    id::Int
    type::ResourceType
    compute_speed::Float64      # Relative speed (1.0 = baseline)
    memory_bandwidth::Float64   # GB/s
    available_time::Float64     # Next available time
    max_memory::Int64           # Bytes
    used_memory::Int64          # Bytes
    power_watts::Float64        # Power consumption
end

"""
Task execution profile on different resource types
"""
struct TaskExecutionProfile
    task_id::String
    execution_times::Dict{ResourceType, Float64}  # Execution time per resource type
    memory_required::Int64                         # Bytes
    data_size::Int64                              # Bytes (for communication)
    priority::Float64                             # User-defined priority
end

"""
Communication cost matrix between resources
"""
struct CommunicationMatrix
    bandwidth::Dict{Tuple{Int, Int}, Float64}  # (src_resource, dst_resource) -> bandwidth (MB/s)
    latency::Dict{Tuple{Int, Int}, Float64}    # (src_resource, dst_resource) -> latency (ms)
end

"""
Scheduled task with timing information
"""
mutable struct ScheduledTask
    task_id::String
    resource_id::Int
    start_time::Float64
    finish_time::Float64
    predecessors::Vector{String}
    data_ready_time::Float64  # When all data from predecessors is available
end

"""
Complete schedule result
"""
struct ScheduleResult
    scheduled_tasks::Vector{ScheduledTask}
    makespan::Float64                    # Total execution time
    resource_utilization::Dict{Int, Float64}  # Per-resource utilization
    total_energy::Float64                # Total energy consumed
    critical_path::Vector{String}        # Critical path task IDs
end

# ============================================================================
# HEFT Algorithm
# ============================================================================

"""
    heft_schedule(
        task_graph::Dict{String, Vector{String}},
        task_profiles::Dict{String, TaskExecutionProfile},
        resources::Vector{Resource},
        comm_matrix::Union{CommunicationMatrix, Nothing}=nothing
    ) -> ScheduleResult

Schedule tasks using HEFT algorithm.

# Arguments
- `task_graph`: DAG of tasks (task_id => list of dependencies)
- `task_profiles`: Execution profiles for each task
- `resources`: Available heterogeneous resources
- `comm_matrix`: Communication costs (optional, uses defaults if nothing)

# Returns
Complete schedule with task assignments and timing
"""
function heft_schedule(
    task_graph::Dict{String, Vector{String}},
    task_profiles::Dict{String, TaskExecutionProfile},
    resources::Vector{Resource},
    comm_matrix::Union{CommunicationMatrix, Nothing}=nothing
)::ScheduleResult
    
    # Initialize communication matrix if not provided
    if comm_matrix === nothing
        comm_matrix = create_default_communication_matrix(resources)
    end
    
    # Phase 1: Calculate task priorities (upward rank)
    priorities = calculate_upward_ranks(task_graph, task_profiles, resources, comm_matrix)
    
    # Phase 2: Sort tasks by priority (descending)
    sorted_tasks = sort(collect(keys(task_graph)), by=t->priorities[t], rev=true)
    
    # Phase 3: Schedule each task
    schedule = ScheduledTask[]
    task_finish_times = Dict{String, Float64}()
    task_resources = Dict{String, Int}()
    
    # Reset resource availability
    for resource in resources
        resource.available_time = 0.0
        resource.used_memory = 0
    end
    
    for task_id in sorted_tasks
        # Find best resource for this task
        best_resource, best_start, best_finish = select_best_resource(
            task_id,
            task_profiles[task_id],
            task_graph[task_id],
            resources,
            task_finish_times,
            task_resources,
            comm_matrix
        )
        
        # Calculate data ready time
        data_ready_time = calculate_data_ready_time(
            task_id,
            task_graph[task_id],
            task_finish_times,
            task_resources,
            best_resource.id,
            task_profiles,
            comm_matrix
        )
        
        # Create scheduled task
        scheduled_task = ScheduledTask(
            task_id,
            best_resource.id,
            best_start,
            best_finish,
            task_graph[task_id],
            data_ready_time
        )
        
        push!(schedule, scheduled_task)
        
        # Update state
        task_finish_times[task_id] = best_finish
        task_resources[task_id] = best_resource.id
        best_resource.available_time = best_finish
        
        # Update memory usage
        memory_req = task_profiles[task_id].memory_required
        if best_resource.used_memory + memory_req > best_resource.max_memory
            @warn "Memory overflow on resource $(best_resource.id)"
        end
        best_resource.used_memory += memory_req
    end
    
    # Calculate statistics
    makespan = maximum(st.finish_time for st in schedule)
    utilization = calculate_resource_utilization(schedule, resources, makespan)
    total_energy = calculate_total_energy(schedule, resources)
    critical_path = find_critical_path_schedule(schedule, task_graph)
    
    return ScheduleResult(
        schedule,
        makespan,
        utilization,
        total_energy,
        critical_path
    )
end

# ============================================================================
# Priority Calculation (Upward Rank)
# ============================================================================

"""
    calculate_upward_ranks(
        task_graph::Dict{String, Vector{String}},
        task_profiles::Dict{String, TaskExecutionProfile},
        resources::Vector{Resource},
        comm_matrix::CommunicationMatrix
    ) -> Dict{String, Float64}

Calculate upward rank for each task (priority metric).

Upward rank: rank_u(task) = w̄(task) + max(c̄(task, succ) + rank_u(succ))
where:
- w̄(task) = average execution time across all resources
- c̄(task, succ) = average communication cost to successor
"""
function calculate_upward_ranks(
    task_graph::Dict{String, Vector{String}},
    task_profiles::Dict{String, TaskExecutionProfile},
    resources::Vector{Resource},
    comm_matrix::CommunicationMatrix
)::Dict{String, Float64}
    
    ranks = Dict{String, Float64}()
    
    # Find successors for each task
    successors = find_successors(task_graph)
    
    # Compute ranks recursively (bottom-up)
    function compute_rank(task_id::String)::Float64
        if haskey(ranks, task_id)
            return ranks[task_id]
        end
        
        # Average execution time
        avg_exec_time = calculate_average_execution_time(
            task_profiles[task_id],
            resources
        )
        
        # Maximum rank of successors
        max_successor_rank = 0.0
        
        if haskey(successors, task_id)
            for succ_id in successors[task_id]
                # Average communication cost
                avg_comm_cost = calculate_average_communication_cost(
                    task_profiles[task_id],
                    task_profiles[succ_id],
                    comm_matrix
                )
                
                # Recursive rank computation
                succ_rank = compute_rank(succ_id)
                successor_rank = avg_comm_cost + succ_rank
                
                max_successor_rank = max(max_successor_rank, successor_rank)
            end
        end
        
        rank = avg_exec_time + max_successor_rank
        ranks[task_id] = rank
        
        return rank
    end
    
    # Compute ranks for all tasks
    for task_id in keys(task_graph)
        compute_rank(task_id)
    end
    
    return ranks
end

function find_successors(task_graph::Dict{String, Vector{String}})::Dict{String, Vector{String}}
    successors = Dict{String, Vector{String}}()
    
    for task_id in keys(task_graph)
        successors[task_id] = String[]
    end
    
    for (task_id, deps) in task_graph
        for dep_id in deps
            if haskey(successors, dep_id)
                push!(successors[dep_id], task_id)
            else
                successors[dep_id] = [task_id]
            end
        end
    end
    
    return successors
end

function calculate_average_execution_time(
    profile::TaskExecutionProfile,
    resources::Vector{Resource}
)::Float64
    
    total_time = 0.0
    count = 0
    
    for resource in resources
        if haskey(profile.execution_times, resource.type)
            exec_time = profile.execution_times[resource.type] / resource.compute_speed
            total_time += exec_time
            count += 1
        end
    end
    
    return count > 0 ? total_time / count : Inf
end

function calculate_average_communication_cost(
    src_profile::TaskExecutionProfile,
    dst_profile::TaskExecutionProfile,
    comm_matrix::CommunicationMatrix
)::Float64
    
    # If tasks are on same resource, no communication cost
    data_size_mb = src_profile.data_size / 1e6
    
    # Average across all resource pairs
    total_cost = 0.0
    count = 0
    
    for (edge, bandwidth) in comm_matrix.bandwidth
        latency = get(comm_matrix.latency, edge, 0.0)
        
        if bandwidth > 0
            transfer_time = data_size_mb / bandwidth  # seconds
            comm_cost = latency + transfer_time * 1000  # Convert to ms
            total_cost += comm_cost
            count += 1
        end
    end
    
    return count > 0 ? (total_cost / count) / 1000.0 : 0.0  # Convert back to seconds
end

# ============================================================================
# Resource Selection
# ============================================================================

"""
    select_best_resource(...)

Find resource that gives earliest finish time for task.
"""
function select_best_resource(
    task_id::String,
    profile::TaskExecutionProfile,
    dependencies::Vector{String},
    resources::Vector{Resource},
    task_finish_times::Dict{String, Float64},
    task_resources::Dict{String, Int},
    comm_matrix::CommunicationMatrix
)::Tuple{Resource, Float64, Float64}
    
    best_resource = nothing
    best_start_time = Inf
    best_finish_time = Inf
    
    for resource in resources
        # Check if task can run on this resource type
        if !haskey(profile.execution_times, resource.type)
            continue
        end
        
        # Check memory constraint
        if resource.used_memory + profile.memory_required > resource.max_memory
            continue
        end
        
        # Calculate earliest start time on this resource
        earliest_start = resource.available_time
        
        # Consider data transfer from dependencies
        for dep_id in dependencies
            if haskey(task_finish_times, dep_id) && haskey(task_resources, dep_id)
                dep_finish = task_finish_times[dep_id]
                dep_resource = task_resources[dep_id]
                
                # Communication cost if different resources
                if dep_resource != resource.id
                    comm_cost = calculate_communication_time(
                        profile,
                        dep_resource,
                        resource.id,
                        comm_matrix
                    )
                    data_available = dep_finish + comm_cost
                else
                    data_available = dep_finish
                end
                
                earliest_start = max(earliest_start, data_available)
            end
        end
        
        # Execution time on this resource
        exec_time = profile.execution_times[resource.type] / resource.compute_speed
        finish_time = earliest_start + exec_time
        
        # Select resource with earliest finish time
        if finish_time < best_finish_time
            best_finish_time = finish_time
            best_start_time = earliest_start
            best_resource = resource
        end
    end
    
    if best_resource === nothing
        error("No suitable resource found for task $task_id")
    end
    
    return (best_resource, best_start_time, best_finish_time)
end

function calculate_communication_time(
    profile::TaskExecutionProfile,
    src_resource_id::Int,
    dst_resource_id::Int,
    comm_matrix::CommunicationMatrix
)::Float64
    
    if src_resource_id == dst_resource_id
        return 0.0
    end
    
    edge = (src_resource_id, dst_resource_id)
    
    bandwidth = get(comm_matrix.bandwidth, edge, 100.0)  # MB/s default
    latency = get(comm_matrix.latency, edge, 0.1)        # ms default
    
    data_size_mb = profile.data_size / 1e6
    transfer_time_s = data_size_mb / bandwidth
    latency_s = latency / 1000.0
    
    return latency_s + transfer_time_s
end

function calculate_data_ready_time(
    task_id::String,
    dependencies::Vector{String},
    task_finish_times::Dict{String, Float64},
    task_resources::Dict{String, Int},
    target_resource_id::Int,
    task_profiles::Dict{String, TaskExecutionProfile},
    comm_matrix::CommunicationMatrix
)::Float64
    
    data_ready = 0.0
    
    for dep_id in dependencies
        if haskey(task_finish_times, dep_id) && haskey(task_resources, dep_id)
            dep_finish = task_finish_times[dep_id]
            dep_resource = task_resources[dep_id]
            
            if dep_resource != target_resource_id
                comm_time = calculate_communication_time(
                    task_profiles[dep_id],
                    dep_resource,
                    target_resource_id,
                    comm_matrix
                )
                data_available = dep_finish + comm_time
            else
                data_available = dep_finish
            end
            
            data_ready = max(data_ready, data_available)
        end
    end
    
    return data_ready
end

# ============================================================================
# Schedule Analysis
# ============================================================================

"""
    calculate_makespan(schedule::Vector{ScheduledTask}) -> Float64

Calculate total execution time (makespan).
"""
function calculate_makespan(schedule::Vector{ScheduledTask})::Float64
    return maximum(st.finish_time for st in schedule)
end

"""
    calculate_resource_utilization(
        schedule::Vector{ScheduledTask},
        resources::Vector{Resource},
        makespan::Float64
    ) -> Dict{Int, Float64}

Calculate utilization percentage for each resource.
"""
function calculate_resource_utilization(
    schedule::Vector{ScheduledTask},
    resources::Vector{Resource},
    makespan::Float64
)::Dict{Int, Float64}
    
    utilization = Dict{Int, Float64}()
    
    for resource in resources
        busy_time = 0.0
        
        for st in schedule
            if st.resource_id == resource.id
                busy_time += st.finish_time - st.start_time
            end
        end
        
        utilization[resource.id] = makespan > 0 ? (busy_time / makespan) * 100.0 : 0.0
    end
    
    return utilization
end

"""
    calculate_total_energy(schedule::Vector{ScheduledTask}, resources::Vector{Resource}) -> Float64

Calculate total energy consumption.
"""
function calculate_total_energy(
    schedule::Vector{ScheduledTask},
    resources::Vector{Resource}
)::Float64
    
    total_energy = 0.0
    
    for st in schedule
        # Find resource
        resource = findfirst(r -> r.id == st.resource_id, resources)
        if resource !== nothing
            exec_time = st.finish_time - st.start_time
            energy = resources[resource].power_watts * exec_time  # Joules
            total_energy += energy
        end
    end
    
    return total_energy
end

"""
    find_critical_path_schedule(
        schedule::Vector{ScheduledTask},
        task_graph::Dict{String, Vector{String}}
    ) -> Vector{String}

Find critical path in the schedule (longest path from entry to exit).
"""
function find_critical_path_schedule(
    schedule::Vector{ScheduledTask},
    task_graph::Dict{String, Vector{String}}
)::Vector{String}
    
    # Build task lookup
    task_lookup = Dict(st.task_id => st for st in schedule)
    
    # Find entry tasks (no dependencies)
    entry_tasks = [tid for (tid, deps) in task_graph if isempty(deps)]
    
    # Find longest path
    longest_path = String[]
    longest_length = 0.0
    
    for entry_task in entry_tasks
        path, length = find_longest_path_from(entry_task, task_lookup, task_graph)
        if length > longest_length
            longest_length = length
            longest_path = path
        end
    end
    
    return longest_path
end

function find_longest_path_from(
    task_id::String,
    task_lookup::Dict{String, ScheduledTask},
    task_graph::Dict{String, Vector{String}}
)::Tuple{Vector{String}, Float64}
    
    if !haskey(task_lookup, task_id)
        return (String[], 0.0)
    end
    
    st = task_lookup[task_id]
    exec_time = st.finish_time - st.start_time
    
    # Find successors
    successors = find_successors(task_graph)
    
    if !haskey(successors, task_id) || isempty(successors[task_id])
        return ([task_id], exec_time)
    end
    
    # Find longest path among successors
    longest_succ_path = String[]
    longest_succ_length = 0.0
    
    for succ_id in successors[task_id]
        succ_path, succ_length = find_longest_path_from(succ_id, task_lookup, task_graph)
        if succ_length > longest_succ_length
            longest_succ_length = succ_length
            longest_succ_path = succ_path
        end
    end
    
    path = vcat([task_id], longest_succ_path)
    length = exec_time + longest_succ_length
    
    return (path, length)
end

# ============================================================================
# Utilities
# ============================================================================

"""
    create_default_communication_matrix(resources::Vector{Resource}) -> CommunicationMatrix

Create default communication matrix assuming network topology.
"""
function create_default_communication_matrix(resources::Vector{Resource})::CommunicationMatrix
    bandwidth_dict = Dict{Tuple{Int, Int}, Float64}()
    latency_dict = Dict{Tuple{Int, Int}, Float64}()
    
    for src in resources
        for dst in resources
            edge = (src.id, dst.id)
            
            if src.id == dst.id
                # Same resource: no communication
                bandwidth_dict[edge] = Inf
                latency_dict[edge] = 0.0
            else
                # Different resources
                bandwidth_dict[edge] = 1000.0  # 1 GB/s
                latency_dict[edge] = 0.1       # 0.1 ms
            end
        end
    end
    
    return CommunicationMatrix(bandwidth_dict, latency_dict)
end

"""
    validate_schedule(
        schedule::Vector{ScheduledTask},
        task_graph::Dict{String, Vector{String}}
    ) -> Bool

Validate that schedule respects task dependencies.
"""
function validate_schedule(
    schedule::Vector{ScheduledTask},
    task_graph::Dict{String, Vector{String}}
)::Bool
    
    task_lookup = Dict(st.task_id => st for st in schedule)
    
    for st in schedule
        deps = task_graph[st.task_id]
        
        for dep_id in deps
            if !haskey(task_lookup, dep_id)
                @error "Dependency $dep_id not scheduled"
                return false
            end
            
            dep_finish = task_lookup[dep_id].finish_time
            if st.start_time < dep_finish
                @error "Task $(st.task_id) starts before dependency $dep_id finishes"
                return false
            end
        end
    end
    
    return true
end

"""
    print_schedule_summary(result::ScheduleResult)

Print human-readable schedule summary.
"""
function print_schedule_summary(result::ScheduleResult)
    println("="^70)
    println("HEFT SCHEDULE SUMMARY")
    println("="^70)
    @printf("Makespan: %.2f seconds\n", result.makespan)
    @printf("Total Energy: %.2f Joules\n", result.total_energy)
    @printf("Number of Tasks: %d\n", length(result.scheduled_tasks))
    
    println("\nResource Utilization:")
    for (res_id, util) in sort(collect(result.resource_utilization))
        @printf("  Resource %d: %.1f%%\n", res_id, util)
    end
    
    println("\nCritical Path:")
    println("  " * join(result.critical_path, " -> "))
    
    println("\nTask Schedule:")
    println("  Task ID       | Resource | Start    | Finish   | Duration")
    println("  " * "-"^66)
    
    for st in sort(result.scheduled_tasks, by=s->s.start_time)
        duration = st.finish_time - st.start_time
        @printf("  %-13s | %8d | %8.2f | %8.2f | %8.2f\n",
                st.task_id, st.resource_id, st.start_time, st.finish_time, duration)
    end
    
    println("="^70)
end

end # module HEFT