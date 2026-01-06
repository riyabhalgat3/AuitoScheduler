"""
src/platform/process_monitor.jl
Real process monitoring with classification
PRODUCTION-STABLE (macOS / Linux compatible)
"""

module ProcessMonitor

using Printf
using Statistics

export get_running_processes, monitor_process, ProcessInfo
export classify_process, classify_process_live, ProcessClass
export get_process_tree, get_heavy_processes, print_process_summary

# ============================================================================
# Data Types
# ============================================================================

struct ProcessInfo
    pid::Int
    name::String
    cpu_percent::Float64
    memory_bytes::Int64
    num_threads::Int
    state::String
    command::String
end

@enum ProcessClass begin
    CPU_BOUND
    MEMORY_BOUND
    IO_BOUND
    GPU_COMPUTE
    INTERACTIVE
    BACKGROUND
end

# ============================================================================
# Public API
# ============================================================================

function get_running_processes(min_cpu::Float64=0.5)::Vector{ProcessInfo}
    if Sys.isapple()
        return get_processes_macos(min_cpu)
    elseif Sys.islinux()
        return get_processes_linux(min_cpu)
    else
        @warn "Process monitoring not supported on $(Sys.KERNEL)"
        return ProcessInfo[]
    end
end

# ============================================================================
# macOS IMPLEMENTATION (FIXED)
# ============================================================================

function get_processes_macos(min_cpu::Float64)::Vector{ProcessInfo}
    processes = ProcessInfo[]

    try
        # Explicit column selection avoids parsing ambiguity
        cmd = `ps -axo pid,pcpu,pmem,state,comm`
        output = read(cmd, String)
        lines = split(output, '\n')[2:end]  # skip header

        total_mem = Sys.total_memory()

        for line in lines
            isempty(strip(line)) && continue
            parts = split(strip(line))
            length(parts) < 5 && continue

            try
                pid      = parse(Int, parts[1])
                cpu_pct  = parse(Float64, parts[2])
                mem_pct  = parse(Float64, parts[3])
                state    = parts[4]
                command  = join(parts[5:end], " ")

                cpu_pct < min_cpu && continue

                # 🔑 FIX: explicit rounding
                mem_bytes = floor(Int, (mem_pct / 100.0) * total_mem)

                name = basename(first(split(command)))

                push!(processes, ProcessInfo(
                    pid,
                    name,
                    cpu_pct,
                    mem_bytes,
                    1,
                    state,
                    command
                ))
            catch
                continue
            end
        end

        sort!(processes, by = p -> p.cpu_percent, rev = true)

    catch e
        @error "macOS process scan failed" exception = e
    end

    return processes
end

# ============================================================================
# Linux IMPLEMENTATION
# ============================================================================

function get_processes_linux(min_cpu::Float64)::Vector{ProcessInfo}
    processes = ProcessInfo[]

    try
        cmd = `ps -eo pid,pcpu,pmem,state,comm --sort=-pcpu`
        output = read(cmd, String)
        lines = split(output, '\n')[2:end]

        total_mem = Sys.total_memory()

        for line in lines
            isempty(strip(line)) && continue
            parts = split(strip(line))
            length(parts) < 5 && continue

            try
                pid     = parse(Int, parts[1])
                cpu_pct = parse(Float64, parts[2])
                mem_pct = parse(Float64, parts[3])
                state   = parts[4]
                command = join(parts[5:end], " ")

                cpu_pct < min_cpu && continue

                mem_bytes = floor(Int, (mem_pct / 100.0) * total_mem)
                name = basename(command)

                push!(processes, ProcessInfo(
                    pid,
                    name,
                    cpu_pct,
                    mem_bytes,
                    1,
                    state,
                    command
                ))
            catch
                continue
            end
        end

        sort!(processes, by = p -> p.cpu_percent, rev = true)

    catch e
        @error "Linux process scan failed" exception = e
    end

    return processes
end

# ============================================================================
# Classification Logic
# ============================================================================

function classify_process(proc::ProcessInfo)::ProcessClass
    cpu = proc.cpu_percent
    mem = proc.memory_bytes

    if cpu > 80
        CPU_BOUND
    elseif cpu > 50 && mem > 4_000_000_000
        MEMORY_BOUND
    elseif cpu > 30
        occursin(r"cuda|metal|torch|tensorflow|julia", lowercase(proc.command)) ?
            GPU_COMPUTE : IO_BOUND
    elseif cpu > 5
        INTERACTIVE
    else
        BACKGROUND
    end
end

# ============================================================================
# Utilities
# ============================================================================

function get_heavy_processes(count::Int=10)
    procs = get_running_processes(0.0)
    sort!(procs, by = p -> p.cpu_percent, rev = true)
    return procs[1:min(count, length(procs))]
end

function print_process_summary(; count::Int=15)
    procs = get_heavy_processes(count)

    println("\n" * "="^80)
    println("TOP $count PROCESSES BY CPU USAGE")
    println("="^80)
    @printf("%-8s %-22s %7s %10s %14s\n",
            "PID", "NAME", "CPU%", "MEM(GB)", "CLASS")
    println("-"^80)

    for p in procs
        cls = classify_process(p)
        @printf("%-8d %-22s %6.1f %10.2f %14s\n",
                p.pid,
                p.name[1:min(22,end)],
                p.cpu_percent,
                p.memory_bytes / 1e9,
                string(cls))
    end

    println("="^80)
end

# ============================================================================
# Live Monitoring (used by LiveScheduler)
# ============================================================================

function monitor_process(pid::Int; duration::Int=30, interval::Float64=1.0)
    samples = ProcessInfo[]
    start = time()

    while time() - start < duration
        procs = get_running_processes(0.0)
        idx = findfirst(p -> p.pid == pid, procs)
        idx !== nothing && push!(samples, procs[idx])
        sleep(interval)
    end

    return samples
end

function classify_process_live(pid::Int; duration::Int=20, interval::Float64=1.0)
    samples = monitor_process(pid; duration, interval)
    isempty(samples) && return (BACKGROUND, Dict())

    cpu_vals = [p.cpu_percent for p in samples]
    mem_vals = [p.memory_bytes for p in samples]

    stats = Dict(
        "cpu_mean" => mean(cpu_vals),
        "cpu_max"  => maximum(cpu_vals),
        "mem_max"  => maximum(mem_vals),
        "samples"  => length(samples)
    )

    return (classify_process(samples[end]), stats)
end

function get_process_tree(pid::Int)
    ProcessInfo[]
end

end # module ProcessMonitor
