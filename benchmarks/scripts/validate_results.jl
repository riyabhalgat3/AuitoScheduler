#!/usr/bin/env julia
# benchmarks/scripts/validate_results.jl
# Statistical validation of benchmark results

using Statistics
using Printf
using JSON3
using Dates

const SIGNIFICANCE_LEVEL = 0.05
const MIN_SAMPLES = 3

println("AutoScheduler Benchmark Result Validator\n")

function load_results(dir::String)
    results_file = joinpath(dir, "results.json")
    if !isfile(results_file)
        error("Results file not found: $results_file")
    end
    
    data = open(results_file, "r") do io
        JSON3.read(io)
    end
    
    return data
end

function validate_sample_size(baseline, scheduled)
    n_baseline = length(baseline)
    n_scheduled = length(scheduled)
    
    println("Sample Size Validation:")
    @printf("  Baseline samples:   %d\n", n_baseline)
    @printf("  Scheduled samples:  %d\n", n_scheduled)
    
    if n_baseline < MIN_SAMPLES || n_scheduled < MIN_SAMPLES
        println("  ⚠ Warning: Insufficient samples (minimum: $MIN_SAMPLES)")
        return false
    else
        println("  ✓ Sample size adequate")
        return true
    end
end

function check_variance(samples::Vector{Float64}, metric_name::String)
    if length(samples) < 2
        return false
    end
    
    μ = mean(samples)
    σ = std(samples)
    cv = σ / μ  # Coefficient of variation
    
    @printf("  %s: μ=%.3f, σ=%.3f, CV=%.2f%%\n", 
            metric_name, μ, σ, cv * 100)
    
    # High variance warning (CV > 20%)
    if cv > 0.2
        println("    ⚠ High variance detected")
        return false
    else
        println("    ✓ Variance acceptable")
        return true
    end
end

function welch_t_test(sample1::Vector{Float64}, sample2::Vector{Float64})
    n1, n2 = length(sample1), length(sample2)
    μ1, μ2 = mean(sample1), mean(sample2)
    s1², s2² = var(sample1), var(sample2)
    
    # Welch's t-statistic
    t = (μ1 - μ2) / sqrt(s1²/n1 + s2²/n2)
    
    # Degrees of freedom (Welch-Satterthwaite)
    df = (s1²/n1 + s2²/n2)^2 / ((s1²/n1)^2/(n1-1) + (s2²/n2)^2/(n2-1))
    
    # Critical value for two-tailed test (approximation)
    # For proper implementation, use Distributions.jl
    t_critical = 2.0  # Rough approximation for α=0.05
    
    significant = abs(t) > t_critical
    
    return (
        t_statistic = t,
        df = df,
        significant = significant,
        mean_diff = μ1 - μ2
    )
end

function validate_statistical_significance(baseline, scheduled)
    println("\nStatistical Significance:")
    
    # Extract time metrics
    baseline_times = [r.execution_time_s for r in baseline]
    scheduled_times = [r.execution_time_s for r in scheduled]
    
    test_result = welch_t_test(baseline_times, scheduled_times)
    
    @printf("  t-statistic: %.3f\n", test_result.t_statistic)
    @printf("  Degrees of freedom: %.1f\n", test_result.df)
    @printf("  Mean difference: %.3f seconds\n", test_result.mean_diff)
    @printf("  Significant: %s\n", test_result.significant ? "Yes ✓" : "No")
    
    if !test_result.significant
        println("  ⚠ Results are not statistically significant")
        println("    Consider collecting more samples or checking for issues")
        return false
    else
        println("  ✓ Results are statistically significant")
        return true
    end
end

function check_outliers(samples::Vector{Float64}, metric_name::String)
    if length(samples) < 3
        return true
    end
    
    q1 = quantile(samples, 0.25)
    q3 = quantile(samples, 0.75)
    iqr = q3 - q1
    
    lower_fence = q1 - 1.5 * iqr
    upper_fence = q3 + 1.5 * iqr
    
    outliers = filter(x -> x < lower_fence || x > upper_fence, samples)
    
    if !isempty(outliers)
        @printf("  ⚠ %s: %d outlier(s) detected\n", 
                metric_name, length(outliers))
        @printf("    Range: [%.3f, %.3f]\n", minimum(samples), maximum(samples))
        @printf("    Outliers: %s\n", join([@sprintf("%.3f", x) for x in outliers], ", "))
        return false
    else
        @printf("  ✓ %s: No outliers detected\n", metric_name)
        return true
    end
end

function validate_improvements(comparison)
    println("\nImprovement Validation:")
    
    improvements = comparison.improvements
    
    time_imp = improvements["time_improvement_pct"]
    energy_imp = improvements["energy_savings_pct"]
    speedup = improvements["speedup"]
    
    @printf("  Time improvement:   %+.1f%%\n", time_imp)
    @printf("  Energy savings:     %+.1f%%\n", energy_imp)
    @printf("  Speedup:            %.2fx\n", speedup)
    
    issues = []
    
    # Check for unrealistic improvements
    if abs(time_imp) > 100
        push!(issues, "Unrealistic time improvement (>100%)")
    end
    
    if abs(energy_imp) > 100
        push!(issues, "Unrealistic energy savings (>100%)")
    end
    
    if speedup < 0.1 || speedup > 10
        push!(issues, "Unrealistic speedup (<0.1x or >10x)")
    end
    
    # Check for negative improvements (regressions)
    if time_imp < -5
        push!(issues, "Significant time regression")
    end
    
    if energy_imp < -5
        push!(issues, "Significant energy regression")
    end
    
    if isempty(issues)
        println("  ✓ All improvements are realistic")
        return true
    else
        println("  ⚠ Issues detected:")
        for issue in issues
            println("    - $issue")
        end
        return false
    end
end

function generate_validation_report(dir::String, results::Dict)
    report_file = joinpath(dir, "validation_report.txt")
    
    open(report_file, "w") do io
        write(io, "Benchmark Validation Report\n")
        write(io, "="^70 * "\n")
        write(io, "Generated: $(now())\n\n")
        
        write(io, "Validation Results:\n")
        write(io, "-"^70 * "\n")
        
        for (key, value) in results
            status = value ? "PASS ✓" : "FAIL ✗"
            write(io, @sprintf("  %-40s %s\n", key, status))
        end
        
        write(io, "\n")
        
        all_pass = all(values(results))
        if all_pass
            write(io, "Overall: ALL CHECKS PASSED ✓\n")
        else
            write(io, "Overall: SOME CHECKS FAILED ✗\n")
            write(io, "\nRecommendations:\n")
            write(io, "  - Increase number of iterations\n")
            write(io, "  - Check for system instability\n")
            write(io, "  - Review benchmark implementation\n")
        end
    end
    
    println("\nValidation report saved: $report_file")
end

# Main validation logic
function main()
    if length(ARGS) < 1
        println("Usage: julia validate_results.jl RESULT_DIR")
        println("\nExample:")
        println("  julia validate_results.jl benchmarks/results/20260104_120000")
        exit(1)
    end
    
    result_dir = ARGS[1]
    
    if !isdir(result_dir)
        error("Result directory not found: $result_dir")
    end
    
    println("Validating results from: $result_dir\n")
    println("="^70)
    
    # Load results
    data = load_results(result_dir)
    baseline = data["baseline"]
    scheduled = data["scheduled"]
    
    # Track validation results
    validation_results = Dict{String, Bool}()
    
    # 1. Sample size validation
    validation_results["Sample Size"] = validate_sample_size(baseline, scheduled)
    println()
    
    # 2. Variance check
    println("Variance Analysis:")
    baseline_times = [r.execution_time_s for r in baseline]
    scheduled_times = [r.execution_time_s for r in scheduled]
    
    var_baseline = check_variance(baseline_times, "Baseline")
    var_scheduled = check_variance(scheduled_times, "Scheduled")
    validation_results["Variance"] = var_baseline && var_scheduled
    
    # 3. Outlier detection
    println("\nOutlier Detection:")
    outlier_baseline = check_outliers(baseline_times, "Baseline")
    outlier_scheduled = check_outliers(scheduled_times, "Scheduled")
    validation_results["Outliers"] = outlier_baseline && outlier_scheduled
    
    # 4. Statistical significance
    validation_results["Significance"] = validate_statistical_significance(baseline, scheduled)
    
    # 5. Improvement validation
    using ..BenchmarkFramework
    comparison = compare_results(baseline, scheduled)
    validation_results["Improvements"] = validate_improvements(comparison)
    
    # Generate report
    println("\n" * "="^70)
    println("VALIDATION SUMMARY")
    println("="^70)
    
    for (check, passed) in validation_results
        status = passed ? "PASS ✓" : "FAIL ✗"
        @printf("  %-30s %s\n", check, status)
    end
    
    all_passed = all(values(validation_results))
    
    println("\n" * "="^70)
    if all_passed
        println("✓ ALL VALIDATION CHECKS PASSED")
        println("  Results are statistically valid and reliable")
    else
        println("✗ SOME VALIDATION CHECKS FAILED")
        println("  Review the issues above and consider re-running benchmarks")
    end
    println("="^70)
    
    # Generate report file
    generate_validation_report(result_dir, validation_results)
    
    # Exit with appropriate code
    exit(all_passed ? 0 : 1)
end

# Run main
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end