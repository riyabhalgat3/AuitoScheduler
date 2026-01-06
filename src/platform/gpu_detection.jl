module GPUDetection
using Printf
using Statistics

export get_gpu_info, GPUInfo, monitor_gpu

struct GPUInfo
    id::Int
    name::String
    vendor::String
    memory_total_bytes::Int64
    memory_used_bytes::Int64
    memory_free_bytes::Int64
    utilization_percent::Float64
    memory_utilization_percent::Float64
    temperature_celsius::Union{Float64, Nothing}
    power_watts::Union{Float64, Nothing}
    clock_speed_mhz::Union{Float64, Nothing}
    pcie_generation::Union{Int, Nothing}
    driver_version::String
    compute_capability::String
end

# ============================================================================
# Public API
# ============================================================================

function get_gpu_info()::Vector{GPUInfo}
    gpus = GPUInfo[]

    append!(gpus, detect_nvidia_gpus())
    append!(gpus, detect_amd_gpus())
    append!(gpus, detect_intel_gpus())
    append!(gpus, detect_apple_gpus())

    return gpus
end

# ============================================================================
# NVIDIA (CUDA)
# ============================================================================

function detect_nvidia_gpus()::Vector{GPUInfo}
    gpus = GPUInfo[]

    smi = Sys.which("nvidia-smi")
    if smi === nothing
        return gpus
    end

    try
        cmd = """
        nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free,utilization.gpu,utilization.memory,temperature.gpu,power.draw,clocks.current.graphics,pcie.link.gen.current,driver_version,compute_cap --format=csv,noheader,nounits
        """
        output = read(`bash -c $cmd`, String)

        for line in split(output, '\n')
            isempty(strip(line)) && continue
            parts = split(line, ',')

            length(parts) < 13 && continue

            push!(gpus, GPUInfo(
                parse(Int, strip(parts[1])),
                strip(parts[2]),
                "NVIDIA",
                parse(Int64, strip(parts[3])) * 1_048_576,
                parse(Int64, strip(parts[4])) * 1_048_576,
                parse(Int64, strip(parts[5])) * 1_048_576,
                parse(Float64, strip(parts[6])),
                parse(Float64, strip(parts[7])),
                parse(Float64, strip(parts[8])),
                parse(Float64, strip(parts[9])),
                parse(Float64, strip(parts[10])),
                parse(Int, strip(parts[11])),
                strip(parts[12]),
                strip(parts[13])
            ))
        end
    catch
        # NVIDIA present but driver inaccessible
    end

    return gpus
end

# ============================================================================
# AMD (ROCm)
# ============================================================================

function detect_amd_gpus()::Vector{GPUInfo}
    gpus = GPUInfo[]

    if Sys.which("rocm-smi") === nothing
        return gpus
    end

    # Minimal safe stub (ROCm parsing varies wildly)
    try
        text = read(`rocm-smi`, String)
        occursin("GPU", text) || return gpus

        push!(gpus, GPUInfo(
            0, "AMD GPU", "AMD",
            0, 0, 0,
            0.0, 0.0,
            nothing, nothing, nothing, nothing,
            "Unknown", "ROCm"
        ))
    catch
    end

    return gpus
end

# ============================================================================
# Intel (oneAPI / iGPU)
# ============================================================================

function detect_intel_gpus()::Vector{GPUInfo}
    gpus = GPUInfo[]

    if Sys.which("xpu-smi") === nothing && !Sys.islinux()
        return gpus
    end

    if Sys.islinux()
        try
            for card in readdir("/sys/class/drm")
                vendor = "/sys/class/drm/$card/device/vendor"
                isfile(vendor) || continue
                occursin("0x8086", read(vendor, String)) || continue

                push!(gpus, GPUInfo(
                    length(gpus),
                    "Intel iGPU",
                    "Intel",
                    0, 0, 0,
                    0.0, 0.0,
                    nothing, nothing, nothing, nothing,
                    "Unknown", "Intel Graphics"
                ))
            end
        catch
        end
    end

    return gpus
end

# ============================================================================
# Apple Silicon (Metal)
# ============================================================================

function detect_apple_gpus()::Vector{GPUInfo}
    gpus = GPUInfo[]

    Sys.isapple() || return gpus
    string(Sys.ARCH) == "x86_64" && return gpus

    try
        sp = read(`system_profiler SPDisplaysDataType`, String)
        occursin("Apple", sp) || return gpus

        push!(gpus, GPUInfo(
            0,
            "Apple Silicon GPU",
            "Apple",
            Sys.total_memory(),
            0,
            Sys.total_memory(),
            0.0,
            0.0,
            nothing,
            nothing,
            nothing,
            nothing,
            "macOS",
            "Metal"
        ))
    catch
    end

    return gpus
end

# ============================================================================
# Monitoring
# ============================================================================

function monitor_gpu(gpu_id::Int=0; duration::Int=60, interval::Float64=1.0)
    start = time()
    samples = GPUInfo[]

    while time() - start < duration
        gpus = get_gpu_info()
        gpu_id < length(gpus) || break
        push!(samples, gpus[gpu_id + 1])
        sleep(interval)
    end

    return samples
end

end # module
