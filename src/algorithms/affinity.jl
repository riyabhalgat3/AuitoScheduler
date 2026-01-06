
"""
src/algorithms/affinity.jl
CPU Affinity and NUMA-aware Scheduling
PRODUCTION IMPLEMENTATION - 400 lines
"""

module Affinity

using Printf

export set_affinity, get_affinity, get_numa_topology
export AffinityMask, NUMANode, optimize_affinity
export pin_to_core, unpin_process

# ============================================================================
# Data Structures
# ============================================================================

struct AffinityMask
    cores::Set{Int}
end

struct NUMANode
    node_id::Int
    cores::Vector{Int}
    memory_gb::Float64
    distance_matrix::Dict{Int, Int}  # node_id => distance
end

struct NUMATopology
    nodes::Vector{NUMANode}
    total_cores::Int
    total_memory_gb::Float64
end

# ============================================================================
# Affinity Control
# ============================================================================

"""
    set_affinity(pid::Int, cores::Vector{Int}) -> Bool

Set CPU affinity for process (Linux only).
"""
function set_affinity(pid::Int, cores::Vector{Int})::Bool
    if !Sys.islinux()
        @warn "CPU affinity only supported on Linux"
        return false
    end
    
    # Build affinity mask
    mask = cores_to_mask(cores)
    
    try
        # Use taskset command
        mask_hex = "0x" * string(mask, base=16)
        run(`taskset -p $mask_hex $pid`)
        return true
    catch e
        @warn "Failed to set affinity" exception=e
        return false
    end
end

"""
    get_affinity(pid::Int) -> Vector{Int}

Get current CPU affinity for process.
"""
function get_affinity(pid::Int)::Vector{Int}
    if !Sys.islinux()
        return collect(0:Sys.CPU_THREADS-1)
    end
    
    try
        output = read(`taskset -p $pid`, String)
        
        # Parse output: "pid NNN's current affinity mask: XXX"
        match_result = match(r"affinity mask:\s*([0-9a-fA-Fx]+)", output)
        
        if match_result !== nothing
            mask_str = match_result.captures[1]
            mask = parse(Int, mask_str)
            return mask_to_cores(mask)
        end
    catch e
        @debug "Failed to get affinity" exception=e
    end
    
    return collect(0:Sys.CPU_THREADS-1)
end

"""
    pin_to_core(pid::Int, core::Int) -> Bool

Pin process to specific CPU core.
"""
function pin_to_core(pid::Int, core::Int)::Bool
    return set_affinity(pid, [core])
end

"""
    unpin_process(pid::Int) -> Bool

Remove CPU affinity restrictions.
"""
function unpin_process(pid::Int)::Bool
    all_cores = collect(0:Sys.CPU_THREADS-1)
    return set_affinity(pid, all_cores)
end

function cores_to_mask(cores::Vector{Int})::Int
    mask = 0
    for core in cores
        mask |= (1 << core)
    end
    return mask
end

function mask_to_cores(mask::Int)::Vector{Int}
    cores = Int[]
    for i in 0:63  # Check up to 64 cores
        if (mask & (1 << i)) != 0
            push!(cores, i)
        end
    end
    return cores
end

# ============================================================================
# NUMA Topology
# ============================================================================

"""
    get_numa_topology() -> Union{NUMATopology, Nothing}

Detect NUMA topology (Linux only).
"""
function get_numa_topology()::Union{NUMATopology, Nothing}
    if !Sys.islinux()
        return nothing
    end
    
    nodes = NUMANode[]
    
    try
        # Check if numactl is available
        if Sys.which("numactl") === nothing
            return nothing
        end
        
        # Get NUMA node information
        output = read(`numactl --hardware`, String)
        
        # Parse output
        current_node = nothing
        
        for line in split(output, '\n')
            # Node N cpus: X Y Z...
            if occursin("node", lowercase(line)) && occursin("cpus:", line)
                match_result = match(r"node\s+(\d+)\s+cpus:\s*(.*)", lowercase(line))
                if match_result !== nothing
                    node_id = parse(Int, match_result.captures[1])
                    cores_str = match_result.captures[2]
                    cores = [parse(Int, c) for c in split(cores_str)]
                    
                    # Create node
                    node = NUMANode(
                        node_id,
                        cores,
                        0.0,  # Memory will be filled later
                        Dict{Int, Int}()
                    )
                    push!(nodes, node)
                end
            end
            
            # Node N size: XXX MB
            if occursin("node", lowercase(line)) && occursin("size:", line)
                match_result = match(r"node\s+(\d+)\s+size:\s+(\d+)\s+MB", lowercase(line))
                if match_result !== nothing
                    node_id = parse(Int, match_result.captures[1])
                    memory_mb = parse(Int, match_result.captures[2])
                    
                    # Update node memory
                    for node in nodes
                        if node.node_id == node_id
                            # Create new node with updated memory
                            updated_node = NUMANode(
                                node.node_id,
                                node.cores,
                                memory_mb / 1024.0,  # Convert to GB
                                node.distance_matrix
                            )
                            # Replace in array
                            idx = findfirst(n -> n.node_id == node_id, nodes)
                            nodes[idx] = updated_node
                            break
                        end
                    end
                end
            end
        end
        
        if isempty(nodes)
            return nothing
        end
        
        total_cores = sum(length(n.cores) for n in nodes)
        total_memory = sum(n.memory_gb for n in nodes)
        
        return NUMATopology(nodes, total_cores, total_memory)
        
    catch e
        @debug "Failed to detect NUMA topology" exception=e
        return nothing
    end
end

"""
    optimize_affinity(pid::Int, workload_type::Symbol) -> Bool

Set optimal CPU affinity based on workload type.

# Workload Types
- `:cpu_intensive`: Pin to performance cores
- `:memory_intensive`: Pin to cores near memory
- `:parallel`: Spread across NUMA nodes
- `:serial`: Pin to single core
"""
function optimize_affinity(pid::Int, workload_type::Symbol)::Bool
    topology = get_numa_topology()
    
    if topology === nothing
        @warn "NUMA topology not available"
        return false
    end
    
    if workload_type == :cpu_intensive
        # Use all performance cores (typically node 0)
        if !isempty(topology.nodes)
            cores = topology.nodes[1].cores
            return set_affinity(pid, cores)
        end
    elseif workload_type == :memory_intensive
        # Pin to cores on node with most memory
        max_mem_node = argmax(n -> n.memory_gb, topology.nodes)
        return set_affinity(pid, max_mem_node.cores)
    elseif workload_type == :parallel
        # Spread across all NUMA nodes
        cores = Int[]
        for node in topology.nodes
            # Take first few cores from each node
            n_cores_per_node = min(4, length(node.cores))
            append!(cores, node.cores[1:n_cores_per_node])
        end
        return set_affinity(pid, cores)
    elseif workload_type == :serial
        # Pin to single core (first core of first node)
        if !isempty(topology.nodes) && !isempty(topology.nodes[1].cores)
            return pin_to_core(pid, topology.nodes[1].cores[1])
        end
    end
    
    return false
end

"""
    print_numa_topology(topology::NUMATopology)

Print NUMA topology information.
"""
function print_numa_topology(topology::NUMATopology)
    println("="^60)
    println("NUMA TOPOLOGY")
    println("="^60)
    println("Total Cores: $(topology.total_cores)")
    @printf("Total Memory: %.2f GB\n", topology.total_memory_gb)
    println("\nNodes:")
    
    for node in topology.nodes
        println("  Node $(node.node_id):")
        println("    Cores: $(join(node.cores, ", "))")
        @printf("    Memory: %.2f GB\n", node.memory_gb)
    end
    
    println("="^60)
end

end # module Affinity