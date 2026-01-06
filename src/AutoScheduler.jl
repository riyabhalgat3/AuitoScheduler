module AutoScheduler

# =========================
# Versioning
# =========================

const VERSION = v"1.0.0"
const _ROOT = @__DIR__

using Statistics
using Printf
using Dates

# =========================
# Core includes
# =========================

# Platform
include(joinpath(_ROOT, "platform", "system_metrics.jl"))
include(joinpath(_ROOT, "platform", "gpu_detection.jl"))
include(joinpath(_ROOT, "platform", "process_monitor.jl"))
include(joinpath(_ROOT, "platform", "power_measurement.jl"))

# Scheduling core
include(joinpath(_ROOT, "scheduling", "task_graph.jl"))
include(joinpath(_ROOT, "scheduling", "resource_allocator.jl"))
include(joinpath(_ROOT, "scheduling", "energy_optimizer.jl"))
include(joinpath(_ROOT, "scheduling", "scheduler_core.jl"))

# Algorithms
include(joinpath(_ROOT, "algorithms", "dvfs.jl"))
include(joinpath(_ROOT, "algorithms", "heft.jl"))
include(joinpath(_ROOT, "algorithms", "load_balancing.jl"))
include(joinpath(_ROOT, "algorithms", "affinity.jl"))

# CLI Tools
include(joinpath(_ROOT, "cli", "monitor.jl"))

# Benchmarks
include(joinpath(_ROOT, "benchmarks", "benchmark_framework.jl"))
include(joinpath(_ROOT, "benchmarks", "resnet.jl"))
include(joinpath(_ROOT, "benchmarks", "monte_carlo.jl"))
include(joinpath(_ROOT, "benchmarks", "video_encode.jl"))
include(joinpath(_ROOT, "benchmarks", "dna_sequence.jl"))
include(joinpath(_ROOT, "benchmarks", "mapreduce.jl"))
include(joinpath(_ROOT, "benchmarks", "nonuniform_monte_carlo.jl"))


# =========================
# Controlled imports
# =========================

using .SystemMetrics: get_real_metrics, monitor_system, SystemMetricsData
using .GPUDetection: get_gpu_info, monitor_gpu, GPUInfo
using .ProcessMonitor: get_running_processes, monitor_process,
                       print_process_summary, classify_process,
                       classify_process_live, ProcessClass, ProcessInfo
using .PowerMeasurement: PowerReading

using .SchedulerCore: schedule, ScheduleResult
using .Monitor: MonitorConfig, start_monitor

const Task = SchedulerCore.Task

using .BenchmarkFramework
using .ResNetBenchmark
using .MonteCarloBenchmark
using .VideoEncodeBenchmark
using .DNASequenceBenchmark
using .MapReduceBenchmark
using .NonUniformMonteCarloBenchmark



# =========================
# Public API
# =========================

export VERSION
export schedule, ScheduleResult
export get_real_metrics, monitor_system
export get_gpu_info, monitor_gpu
export get_running_processes, monitor_process, print_process_summary
export classify_process, classify_process_live, ProcessClass
export SystemMetricsData, GPUInfo, ProcessInfo, PowerReading
export MonitorConfig, start_monitor
export NonUniformMCConfig, run_nonuniform_monte_carlo


# NOTE:
# Task is intentionally NOT exported.
# Users must call AutoScheduler.Task(...)

# =========================
# Lazy-loaded LIVE layer
# =========================

const _LIVE_LOADED = Ref(false)

function _load_live_layer()
    if !_LIVE_LOADED[]
        include(joinpath(_ROOT, "scheduling", "live_scheduler.jl"))
        # API stubs
        include(joinpath(_ROOT, "api", "api_stubs.jl"))
        _LIVE_LOADED[] = true
    end
end

export run_live_scheduler, start_rest_server, stop_rest_server
export start_websocket_server, stop_websocket_server

function run_live_scheduler(args...; kwargs...)
    _load_live_layer()
    result = Base.invokelatest(LiveScheduler.run_live_scheduler, args...; kwargs...)
    return result
end

function start_rest_server(args...; kwargs...)
    _load_live_layer()
    return Base.invokelatest(Main.start_rest_server, args...; kwargs...)
end

function stop_rest_server()
    _load_live_layer()
    return Base.invokelatest(Main.stop_rest_server)
end

function start_websocket_server(args...; kwargs...)
    _load_live_layer()
    return Base.invokelatest(Main.start_websocket_server, args...; kwargs...)
end

function stop_websocket_server()
    _load_live_layer()
    return Base.invokelatest(Main.stop_websocket_server)
end

# =========================
# Init
# =========================

function __init__()
    @info "AutoScheduler initialized" version=VERSION kernel=Sys.KERNEL arch=Sys.ARCH
end

end # module AutoScheduler