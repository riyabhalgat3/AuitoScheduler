# test/unit/test_dvfs.jl
using AutoScheduler.DVFS

@testset "DVFS Tests" begin
    @test begin
        freqs = DVFS.get_available_frequencies(0)
        freqs isa Vector{Float64}
    end
    
    @test begin
        cap = DVFS.detect_dvfs_capability(0)
        cap isa DVFS.DVFSCapability
    end
    
    @test begin
        power = DVFS.estimate_power(3000.0, 1.0, 0.5)
        power > 0
    end
    
    @test begin
        # Test frequency detection returns reasonable values
        freqs = DVFS.get_available_frequencies(0)
        @test !isempty(freqs)
        @test all(f -> f > 0, freqs)
        @test all(f -> f < 10000, freqs)  # Less than 10GHz
        @test issorted(freqs)
        true
    end
    
    @test begin
        # Test DVFS capability structure
        cap = DVFS.detect_dvfs_capability(0)
        @test hasfield(typeof(cap), :available)
        @test hasfield(typeof(cap), :min_freq)
        @test hasfield(typeof(cap), :max_freq)
        @test hasfield(typeof(cap), :available_freqs)
        
        if cap.available
            @test cap.min_freq > 0
            @test cap.max_freq > cap.min_freq
            @test !isempty(cap.available_freqs)
        end
        true
    end
    
    @test begin
        # Test current frequency
        freq = DVFS.get_current_frequency(0)
        @test freq > 0
        @test freq < 10000
        true
    end
    
    @test begin
        # Test power estimation with different parameters
        p1 = DVFS.estimate_power(1000.0, 0.8, 0.5)
        p2 = DVFS.estimate_power(3000.0, 1.2, 0.5)
        p3 = DVFS.estimate_power(3000.0, 1.2, 1.0)
        
        @test p1 > 0
        @test p2 > p1  # Higher frequency = more power
        @test p3 > p2  # Higher utilization = more power
        true
    end
    
    @test begin
        # Test energy calculation
        energy = DVFS.calculate_energy(10.0, 2000.0, 1.0)
        @test energy > 0
        true
    end
    
    @test begin
        # Test optimal frequency selection
        freqs = DVFS.get_available_frequencies(0)
        optimal = DVFS.get_optimal_frequency(0.8, 0.3, 100.0, freqs)
        @test optimal in freqs
        true
    end
    
    @test begin
        # Test energy-optimal frequency
        freqs = DVFS.get_available_frequencies(0)
        optimal = DVFS.find_energy_optimal_frequency(
            freqs,
            10.0,  # base execution time
            nothing,  # no deadline
            DVFS.estimate_power
        )
        @test optimal in freqs
        true
    end
    
    @test begin
        # Test with deadline constraint
        freqs = DVFS.get_available_frequencies(0)
        optimal = DVFS.find_energy_optimal_frequency(
            freqs,
            10.0,  # base execution time
            15.0,  # deadline
            DVFS.estimate_power
        )
        @test optimal in freqs
        true
    end
    
    @test begin
        # Test governor enum
        @test DVFS.PERFORMANCE isa DVFS.FrequencyGovernor
        @test DVFS.POWERSAVE isa DVFS.FrequencyGovernor
        @test DVFS.ONDEMAND isa DVFS.FrequencyGovernor
        true
    end
end