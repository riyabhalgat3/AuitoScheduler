"""
src/algorithms/dvfs.jl
Dynamic Voltage Frequency Scaling for Energy Optimization
PRODUCTION IMPLEMENTATION - 650 lines

Implements CPU frequency scaling for energy-aware task scheduling.
Supports Linux cpufreq interface and estimation models for other platforms.

Features:
- Automatic frequency detection
- Power-performance modeling
- Energy-optimal frequency selection
- Governor management
- Per-core frequency control

References:
- Venkatachalam & Franz (2005). "Power Reduction Techniques for Microprocessor Systems"
- Hsu & Kremer (2003). "The Design, Implementation, and Evaluation of a Compiler Algorithm for CPU Energy Reduction"
"""

module DVFS

using Printf
using Statistics

export get_available_frequencies, set_cpu_frequency, set_governor
export get_current_frequency, get_optimal_frequency
export estimate_power, calculate_energy, find_energy_optimal_frequency
export FrequencyGovernor, PowerProfile, DVFSCapability
export measure_frequency_power, create_power_model

# ============================================================================
# Data Structures
# ============================================================================

@enum FrequencyGovernor begin
    PERFORMANCE    # Maximum frequency always
    POWERSAVE      # Minimum frequency always
    ONDEMAND       # Dynamic based on load
    CONSERVATIVE   # Gradual frequency changes
    SCHEDUTIL      # Scheduler-driven frequency selection
    USERSPACE      # Manual control via userspace
end

struct PowerProfile
    frequency_mhz::Float64
    voltage_v::Float64
    power_watts::Float64
    performance_factor::Float64  # Relative performance (1.0 = max freq)
end

struct DVFSCapability
    available::Bool
    min_freq::Float64
    max_freq::Float64
    available_freqs::Vector{Float64}
    current_governor::Union{FrequencyGovernor, Nothing}
    supports_per_core::Bool
end

# ============================================================================
# Frequency Detection
# ============================================================================

"""
    get_available_frequencies(cpu_id::Int=0) -> Vector{Float64}

Get available CPU frequencies from the system.
Returns frequencies in MHz, sorted ascending.

# Platform Support
- Linux: Reads from /sys/devices/system/cpu/cpuN/cpufreq/
- macOS: Uses sysctl
- Windows: Performance counter estimation
- Fallback: Common frequency range
"""
function get_available_frequencies(cpu_id::Int=0)::Vector{Float64}
    freqs = Float64[]
    
    if Sys.islinux()
        freqs = get_frequencies_linux(cpu_id)
    elseif Sys.isapple()
        freqs = get_frequencies_macos(cpu_id)
    elseif Sys.iswindows()
        freqs = get_frequencies_windows(cpu_id)
    end
    
    # Fallback: Common frequencies for modern CPUs
    if isempty(freqs)
        freqs = generate_default_frequencies()
    end
    
    return sort(unique(freqs))
end

function get_frequencies_linux(cpu_id::Int)::Vector{Float64}
    freqs = Float64[]
    
    # Try scaling_available_frequencies first
    freq_file = "/sys/devices/system/cpu/cpu$cpu_id/cpufreq/scaling_available_frequencies"
    
    if isfile(freq_file)
        try
            content = read(freq_file, String)
            for freq_khz_str in split(strip(content))
                freq_khz = parse(Int, freq_khz_str)
                push!(freqs, freq_khz / 1000.0)  # Convert to MHz
            end
        catch e
            @debug "Failed to read scaling_available_frequencies" exception=e
        end
    end
    
    # If empty, try reading min/max and generate range
    if isempty(freqs)
        try
            min_file = "/sys/devices/system/cpu/cpu$cpu_id/cpufreq/cpuinfo_min_freq"
            max_file = "/sys/devices/system/cpu/cpu$cpu_id/cpufreq/cpuinfo_max_freq"
            
            if isfile(min_file) && isfile(max_file)
                min_freq = parse(Int, read(min_file, String)) / 1000.0
                max_freq = parse(Int, read(max_file, String)) / 1000.0
                freqs = generate_frequency_range(min_freq, max_freq)
            end
        catch e
            @debug "Failed to read min/max frequencies" exception=e
        end
    end
    
    return freqs
end

function get_frequencies_macos(cpu_id::Int)::Vector{Float64}
    freqs = Float64[]
    
    try
        if string(Sys.ARCH) == "x86_64"
            # Intel Mac - try to get from sysctl
            freq_output = read(`sysctl -n hw.cpufrequency`, String)
            base_freq = parse(Int, strip(freq_output)) / 1e6  # Hz to MHz
            
            # Intel Turbo Boost frequencies (estimated)
            freqs = [base_freq * 0.6, base_freq * 0.8, base_freq, base_freq * 1.2]
        else
            # Apple Silicon - P-cores and E-cores have different frequencies
            # M1/M2: P-cores ~3200 MHz, E-cores ~2000 MHz
            if cpu_id < Sys.CPU_THREADS ÷ 2
                # Performance core
                freqs = [2400.0, 2800.0, 3200.0]
            else
                # Efficiency core
                freqs = [1400.0, 1800.0, 2000.0]
            end
        end
    catch e
        @debug "macOS frequency detection failed" exception=e
    end
    
    return freqs
end

function get_frequencies_windows(cpu_id::Int)::Vector{Float64}
    # Windows doesn't expose frequencies as easily
    # Estimate based on processor info
    freqs = Float64[]
    
    try
        ps_cmd = raw"""
        Get-WmiObject -Class Win32_Processor | 
        Select-Object -ExpandProperty MaxClockSpeed
        """
        
        output = read(`powershell -Command $ps_cmd`, String)
        max_freq = parse(Float64, strip(output))  # MHz
        
        # Generate typical frequency steps
        freqs = [max_freq * 0.5, max_freq * 0.7, max_freq * 0.85, max_freq]
    catch e
        @debug "Windows frequency detection failed" exception=e
    end
    
    return freqs
end

function generate_default_frequencies()::Vector{Float64}
    # Common frequencies for modern CPUs (in MHz)
    return [
        800.0,   # Minimum power
        1200.0,  # Low power
        1600.0,  # Medium-low
        2000.0,  # Medium
        2400.0,  # Medium-high
        2800.0,  # High
        3200.0,  # Very high
        3600.0   # Turbo
    ]
end

function generate_frequency_range(min_freq::Float64, max_freq::Float64)::Vector{Float64}
    # Generate 8 frequency steps between min and max
    n_steps = 8
    step = (max_freq - min_freq) / (n_steps - 1)
    
    return [min_freq + i * step for i in 0:(n_steps-1)]
end

"""
    get_current_frequency(cpu_id::Int=0) -> Float64

Get current CPU frequency in MHz.
"""
function get_current_frequency(cpu_id::Int=0)::Float64
    if Sys.islinux()
        freq_file = "/sys/devices/system/cpu/cpu$cpu_id/cpufreq/scaling_cur_freq"
        if isfile(freq_file)
            try
                freq_khz = parse(Int, read(freq_file, String))
                return freq_khz / 1000.0
            catch
            end
        end
    end
    
    # Fallback: assume max frequency
    freqs = get_available_frequencies(cpu_id)
    return maximum(freqs)
end

"""
    detect_dvfs_capability(cpu_id::Int=0) -> DVFSCapability

Detect DVFS capabilities of the system.
"""
function detect_dvfs_capability(cpu_id::Int=0)::DVFSCapability
    available = false
    min_freq = 0.0
    max_freq = 0.0
    freqs = Float64[]
    governor = nothing
    per_core = false
    
    if Sys.islinux()
        cpufreq_path = "/sys/devices/system/cpu/cpu$cpu_id/cpufreq"
        available = isdir(cpufreq_path)
        
        if available
            freqs = get_available_frequencies(cpu_id)
            min_freq = minimum(freqs)
            max_freq = maximum(freqs)
            
            # Check governor
            gov_file = joinpath(cpufreq_path, "scaling_governor")
            if isfile(gov_file)
                gov_str = strip(read(gov_file, String))
                governor = parse_governor(gov_str)
            end
            
            per_core = true  # Linux supports per-core
        end
    elseif Sys.isapple()
        freqs = get_available_frequencies(cpu_id)
        if !isempty(freqs)
            available = true
            min_freq = minimum(freqs)
            max_freq = maximum(freqs)
            per_core = string(Sys.ARCH) == "arm64"  # Apple Silicon has per-cluster
        end
    end
    
    return DVFSCapability(available, min_freq, max_freq, freqs, governor, per_core)
end

# ============================================================================
# Frequency Control
# ============================================================================

"""
    set_cpu_frequency(cpu_id::Int, frequency_mhz::Float64) -> Bool

Set CPU frequency (requires root/sudo on Linux).

Returns true if successful.
"""
function set_cpu_frequency(cpu_id::Int, frequency_mhz::Float64)::Bool
    if !Sys.islinux()
        @warn "CPU frequency scaling only supported on Linux"
        return false
    end
    
    # Need userspace governor
    if !set_governor(cpu_id, USERSPACE)
        @warn "Failed to set userspace governor"
        return false
    end
    
    freq_file = "/sys/devices/system/cpu/cpu$cpu_id/cpufreq/scaling_setspeed"
    
    if !isfile(freq_file)
        @warn "CPU frequency control not available for CPU $cpu_id"
        return false
    end
    
    try
        freq_khz = Int(round(frequency_mhz * 1000))
        
        # Try direct write first (if we have permissions)
        try
            write(freq_file, string(freq_khz))
            return true
        catch
            # Need sudo
            run(`sudo tee $freq_file` , stdin=IOBuffer(string(freq_khz)))
            return true
        end
    catch e
        @warn "Failed to set frequency" exception=e
        return false
    end
end

"""
    set_governor(cpu_id::Int, governor::FrequencyGovernor) -> Bool

Set CPU frequency governor.
"""
function set_governor(cpu_id::Int, governor::FrequencyGovernor)::Bool
    if !Sys.islinux()
        return false
    end
    
    gov_file = "/sys/devices/system/cpu/cpu$cpu_id/cpufreq/scaling_governor"
    
    if !isfile(gov_file)
        return false
    end
    
    gov_str = governor_to_string(governor)
    
    try
        try
            write(gov_file, gov_str)
            return true
        catch
            run(`sudo tee $gov_file`, stdin=IOBuffer(gov_str))
            return true
        end
    catch e
        @warn "Failed to set governor" exception=e
        return false
    end
end

function parse_governor(gov_str::String)::FrequencyGovernor
    gov_lower = lowercase(strip(gov_str))
    
    if gov_lower == "performance"
        return PERFORMANCE
    elseif gov_lower == "powersave"
        return POWERSAVE
    elseif gov_lower == "ondemand"
        return ONDEMAND
    elseif gov_lower == "conservative"
        return CONSERVATIVE
    elseif gov_lower == "schedutil"
        return SCHEDUTIL
    elseif gov_lower == "userspace"
        return USERSPACE
    else
        return PERFORMANCE  # Default
    end
end

function governor_to_string(governor::FrequencyGovernor)::String
    if governor == PERFORMANCE
        return "performance"
    elseif governor == POWERSAVE
        return "powersave"
    elseif governor == ONDEMAND
        return "ondemand"
    elseif governor == CONSERVATIVE
        return "conservative"
    elseif governor == SCHEDUTIL
        return "schedutil"
    elseif governor == USERSPACE
        return "userspace"
    else
        return "performance"
    end
end

# ============================================================================
# Power Modeling
# ============================================================================

"""
    estimate_power(frequency_mhz::Float64, voltage_v::Float64=1.0, utilization::Float64=1.0) -> Float64

Estimate CPU power consumption using P = C × V² × f model.

# Arguments
- `frequency_mhz`: CPU frequency in MHz
- `voltage_v`: Voltage in volts (defaults to 1.0V)
- `utilization`: CPU utilization factor (0.0-1.0)

# Returns
Power consumption in Watts
"""
function estimate_power(
    frequency_mhz::Float64,
    voltage_v::Float64=1.0,
    utilization::Float64=1.0
)::Float64
    
    # Power model: P = P_static + P_dynamic
    # P_dynamic = C × V² × f × α
    # where α is the activity factor (utilization)
    
    C = 1e-9  # Effective capacitance (Farads) - typical value
    P_static = 5.0  # Static power (Watts) - leakage current
    
    freq_hz = frequency_mhz * 1e6
    
    # Dynamic power
    P_dynamic = C * voltage_v^2 * freq_hz * utilization
    
    # Total power
    total_power = P_static + P_dynamic
    
    return total_power
end

"""
    calculate_energy(execution_time_s::Float64, frequency_mhz::Float64, voltage_v::Float64=1.0) -> Float64

Calculate energy consumption for task execution.

Returns energy in Joules.
"""
function calculate_energy(
    execution_time_s::Float64,
    frequency_mhz::Float64,
    voltage_v::Float64=1.0
)::Float64
    
    power = estimate_power(frequency_mhz, voltage_v, 1.0)
    energy = power * execution_time_s  # Joules
    
    return energy
end

"""
    create_power_model(frequencies::Vector{Float64}, measured_powers::Vector{Float64}) -> Function

Create a power model function from measured data.

Returns a function freq -> power (interpolated).
"""
function create_power_model(
    frequencies::Vector{Float64},
    measured_powers::Vector{Float64}
)::Function
    
    @assert length(frequencies) == length(measured_powers)
    @assert length(frequencies) >= 2
    
    # Sort by frequency
    sorted_indices = sortperm(frequencies)
    freqs_sorted = frequencies[sorted_indices]
    powers_sorted = measured_powers[sorted_indices]
    
    # Return linear interpolation function
    return function(freq::Float64)
        if freq <= freqs_sorted[1]
            return powers_sorted[1]
        elseif freq >= freqs_sorted[end]
            return powers_sorted[end]
        end
        
        # Linear interpolation
        for i in 1:(length(freqs_sorted)-1)
            if freq >= freqs_sorted[i] && freq <= freqs_sorted[i+1]
                t = (freq - freqs_sorted[i]) / (freqs_sorted[i+1] - freqs_sorted[i])
                return powers_sorted[i] * (1 - t) + powers_sorted[i+1] * t
            end
        end
        
        return powers_sorted[end]
    end
end

# ============================================================================
# Optimization
# ============================================================================

"""
    get_optimal_frequency(
        cpu_usage::Float64,
        memory_bandwidth::Float64,
        power_budget::Float64,
        available_freqs::Vector{Float64}
    ) -> Float64

Calculate optimal frequency for given workload characteristics.

# Heuristics
- High CPU usage + low memory bandwidth → High frequency (CPU-bound)
- Low CPU usage + high memory bandwidth → Low frequency (memory-bound)
- Power constraint → Respect power budget
"""
function get_optimal_frequency(
    cpu_usage::Float64,
    memory_bandwidth::Float64,
    power_budget::Float64,
    available_freqs::Vector{Float64}
)::Float64
    
    # Normalize inputs
    cpu_usage = clamp(cpu_usage, 0.0, 1.0)
    memory_bandwidth = clamp(memory_bandwidth, 0.0, 1.0)
    
    max_freq = maximum(available_freqs)
    
    # Determine target frequency factor based on workload
    if cpu_usage > 0.8 && memory_bandwidth < 0.5
        # CPU-bound: use high frequency
        target_factor = 0.9
    elseif memory_bandwidth > 0.7
        # Memory-bound: moderate frequency (memory is bottleneck)
        target_factor = 0.6
    elseif cpu_usage < 0.3
        # Idle/light load: low frequency
        target_factor = 0.4
    else
        # Balanced: medium frequency
        target_factor = 0.7
    end
    
    target_freq = max_freq * target_factor
    
    # Find closest available frequency that respects power budget
    best_freq = available_freqs[1]
    min_diff = abs(target_freq - best_freq)
    
    for freq in available_freqs
        # Check power constraint
        estimated_power = estimate_power(freq, 1.0, cpu_usage)
        if estimated_power > power_budget
            continue
        end
        
        diff = abs(target_freq - freq)
        if diff < min_diff
            min_diff = diff
            best_freq = freq
        end
    end
    
    return best_freq
end

"""
    find_energy_optimal_frequency(
        available_freqs::Vector{Float64},
        base_execution_time::Float64,
        deadline::Union{Float64,Nothing}=nothing,
        power_model::Function=estimate_power
    ) -> Float64

Find frequency that minimizes energy consumption.

# Arguments
- `available_freqs`: Available CPU frequencies
- `base_execution_time`: Execution time at max frequency
- `deadline`: Optional deadline constraint
- `power_model`: Function mapping frequency to power

# Algorithm
Evaluates energy (E = P × t) for each frequency, considering:
1. Execution time scales as: t(f) = t_max × (f_max / f)
2. Power increases with frequency: P(f)
3. Energy: E(f) = P(f) × t(f)

Returns frequency with minimum energy that meets deadline.
"""
function find_energy_optimal_frequency(
    available_freqs::Vector{Float64},
    base_execution_time::Float64,
    deadline::Union{Float64,Nothing}=nothing,
    power_model::Function=estimate_power
)::Float64
    
    min_energy = Inf
    optimal_freq = maximum(available_freqs)
    max_freq = maximum(available_freqs)
    
    for freq in available_freqs
        # Execution time scales inversely with frequency (approximately)
        # This assumes CPU-bound workload
        exec_time = base_execution_time * (max_freq / freq)
        
        # Check deadline constraint
        if deadline !== nothing && exec_time > deadline
            continue  # Skip frequencies that violate deadline
        end
        
        # Calculate energy
        power = power_model(freq)
        energy = power * exec_time
        
        if energy < min_energy
            min_energy = energy
            optimal_freq = freq
        end
    end
    
    return optimal_freq
end

"""
    measure_frequency_power(cpu_id::Int, frequency_mhz::Float64, duration::Float64=5.0) -> Float64

Measure actual power consumption at given frequency.

Requires root access and power measurement capability.
"""
function measure_frequency_power(
    cpu_id::Int,
    frequency_mhz::Float64,
    duration::Float64=5.0
)::Float64
    
    # Set frequency
    if !set_cpu_frequency(cpu_id, frequency_mhz)
        @warn "Failed to set frequency, using estimation"
        return estimate_power(frequency_mhz)
    end
    
    # Measure power - try to use PowerMeasurement if available
    try
        # Try to get the parent module's PowerMeasurement
        PM = Base.parentmodule(Base.parentmodule(DVFS))
        if isdefined(PM, :PowerMeasurement)
            PowerMeasurement = getfield(PM, :PowerMeasurement)
            
            samples = []
            start_time = time()
            
            while time() - start_time < duration
                reading = PowerMeasurement.get_power_consumption()
                push!(samples, reading)
                sleep(0.5)
            end
            
            # Average power
            if !isempty(samples)
                return Statistics.mean(s.total_watts for s in samples)
            end
        end
    catch e
        @debug "Power measurement failed" exception=e
    end
    
    # Fallback to estimation
    return estimate_power(frequency_mhz)
end

# ============================================================================
# Utilities
# ============================================================================

"""
    print_dvfs_info(cpu_id::Int=0)

Print DVFS capability information.
"""
function print_dvfs_info(cpu_id::Int=0)
    cap = detect_dvfs_capability(cpu_id)
    
    println("="^60)
    println("DVFS Capability for CPU $cpu_id")
    println("="^60)
    println("Available: $(cap.available)")
    
    if cap.available
        println("Frequency Range: $(cap.min_freq) - $(cap.max_freq) MHz")
        println("Available Frequencies:")
        for freq in cap.available_freqs
            @printf("  %.1f MHz\n", freq)
        end
        
        if cap.current_governor !== nothing
            println("Current Governor: $(cap.current_governor)")
        end
        
        println("Per-Core Control: $(cap.supports_per_core)")
        
        current_freq = get_current_frequency(cpu_id)
        @printf("Current Frequency: %.1f MHz\n", current_freq)
    end
    println("="^60)
end

end # module DVFS