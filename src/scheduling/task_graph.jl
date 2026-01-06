module TaskGraph
using Printf
using Statistics
using DataStructures

export TaskDAG, TaskNode, add_task!, add_dependency!, validate_dag!
export topological_sort, find_critical_path, get_ready_tasks

mutable struct TaskNode
    id::String
    dependencies::Set{String}
    dependents::Set{String}
    execution_time::Float64
    earliest_start::Float64
    latest_start::Float64
    slack::Float64
end

struct TaskDAG
    nodes::Dict{String, TaskNode}
    TaskDAG() = new(Dict{String, TaskNode}())
end

function add_task!(dag::TaskDAG, id::String, execution_time::Float64=1.0)
    dag.nodes[id] = TaskNode(id, Set{String}(), Set{String}(), execution_time, 0.0, Inf, 0.0)
end

function add_dependency!(dag::TaskDAG, task::String, depends_on::String)
    push!(dag.nodes[task].dependencies, depends_on)
    push!(dag.nodes[depends_on].dependents, task)
end

function validate_dag!(dag::TaskDAG)::Bool
    return true
end

function topological_sort(dag::TaskDAG)::Vector{String}
    return collect(keys(dag.nodes))
end

function find_critical_path(dag::TaskDAG)::Tuple{Vector{String}, Float64}
    return (Vector{String}(), 0.0)
end

function get_ready_tasks(dag::TaskDAG, completed::Set{String})::Vector{String}
    return Vector{String}()
end

end
