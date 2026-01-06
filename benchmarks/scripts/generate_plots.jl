#!/usr/bin/env julia
# benchmarks/scripts/generate_plots.jl
# Generate visualization plots from benchmark results

using Printf
using Statistics
using JSON3
using Dates

println("AutoScheduler Benchmark Plot Generator\n")

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

function generate_ascii_bar_chart(values::Vector{Float64}, labels::Vector{String}, 
                                   title::String; width=60)
    println("\n$title")
    println("="^width)
    
    max_val = maximum(abs.(values))
    
    for (label, val) in zip(labels, values)
        bar_len = Int(round(abs(val) / max_val * (width - 25)))
        bar = val >= 0 ? "█"^bar_len : "▓"^bar_len
        sign = val >= 0 ? "+" : ""
        @printf("%-20s %s%.1f%%\n", label, bar, val)
        @printf("%-20s │%s\n", "", bar)
    end
    
    println("="^width)
end

function generate_time_comparison_plot(baseline, scheduled, output_dir)
    baseline_times = [r.execution_time_s for r in baseline]
    scheduled_times = [r.execution_time_s for r in scheduled]
    
    mean_baseline = mean(baseline_times)
    mean_scheduled = mean(scheduled_times)
    
    improvement = (mean_baseline - mean_scheduled) / mean_baseline * 100
    
    println("\nExecution Time Comparison")
    println("="^70)
    @printf("  Baseline:   %.2f ± %.2f seconds\n", 
            mean_baseline, std(baseline_times))
    @printf("  Scheduled:  %.2f ± %.2f seconds\n", 
            mean_scheduled, std(scheduled_times))
    @printf("  Improvement: %.1f%%\n", improvement)
    
    # ASCII bar chart
    println("\n  " * "█"^Int(round(mean_baseline/mean_baseline * 40)) * " Baseline")
    println("  " * "█"^Int(round(mean_scheduled/mean_baseline * 40)) * " Scheduled")
    
    # Save data for plotting
    plot_file = joinpath(output_dir, "time_comparison.txt")
    open(plot_file, "w") do io
        write(io, "# Execution Time Comparison\n")
        write(io, "Baseline_Mean,Baseline_Std,Scheduled_Mean,Scheduled_Std,Improvement\n")
        write(io, @sprintf("%.3f,%.3f,%.3f,%.3f,%.2f\n",
              mean_baseline, std(baseline_times),
              mean_scheduled, std(scheduled_times),
              improvement))
    end
    
    println("  Data saved: $plot_file")
end

function generate_energy_comparison_plot(baseline, scheduled, output_dir)
    baseline_energy = [r.energy_consumed_j for r in baseline]
    scheduled_energy = [r.energy_consumed_j for r in scheduled]
    
    mean_baseline = mean(baseline_energy)
    mean_scheduled = mean(scheduled_energy)
    
    savings = (mean_baseline - mean_scheduled) / mean_baseline * 100
    
    println("\nEnergy Consumption Comparison")
    println("="^70)
    @printf("  Baseline:   %.2f ± %.2f J (%.4f Wh)\n", 
            mean_baseline, std(baseline_energy), mean_baseline/3600)
    @printf("  Scheduled:  %.2f ± %.2f J (%.4f Wh)\n", 
            mean_scheduled, std(scheduled_energy), mean_scheduled/3600)
    @printf("  Savings:    %.1f%%\n", savings)
    
    # ASCII bar chart
    println("\n  " * "█"^Int(round(mean_baseline/mean_baseline * 40)) * " Baseline")
    println("  " * "█"^Int(round(mean_scheduled/mean_baseline * 40)) * " Scheduled")
    
    # Save data
    plot_file = joinpath(output_dir, "energy_comparison.txt")
    open(plot_file, "w") do io
        write(io, "# Energy Consumption Comparison\n")
        write(io, "Baseline_Mean,Baseline_Std,Scheduled_Mean,Scheduled_Std,Savings\n")
        write(io, @sprintf("%.3f,%.3f,%.3f,%.3f,%.2f\n",
              mean_baseline, std(baseline_energy),
              mean_scheduled, std(scheduled_energy),
              savings))
    end
    
    println("  Data saved: $plot_file")
end

function generate_distribution_plot(baseline, scheduled, output_dir)
    baseline_times = [r.execution_time_s for r in baseline]
    scheduled_times = [r.execution_time_s for r in scheduled]
    
    println("\nExecution Time Distribution")
    println("="^70)
    
    # Sort and display
    println("\nBaseline samples:")
    for (i, t) in enumerate(sort(baseline_times))
        print("  ")
        print("█"^Int(round(t / maximum(baseline_times) * 40)))
        @printf(" %.2fs\n", t)
    end
    
    println("\nScheduled samples:")
    for (i, t) in enumerate(sort(scheduled_times))
        print("  ")
        print("█"^Int(round(t / maximum(baseline_times) * 40)))
        @printf(" %.2fs\n", t)
    end
    
    # Save histogram data
    plot_file = joinpath(output_dir, "distribution.txt")
    open(plot_file, "w") do io
        write(io, "# Execution Time Distribution\n")
        write(io, "Sample,Baseline,Scheduled\n")
        max_len = max(length(baseline_times), length(scheduled_times))
        for i in 1:max_len
            b = i <= length(baseline_times) ? baseline_times[i] : NaN
            s = i <= length(scheduled_times) ? scheduled_times[i] : NaN
            write(io, @sprintf("%d,%.3f,%.3f\n", i, b, s))
        end
    end
    
    println("\n  Data saved: $plot_file")
end

function generate_improvement_summary(baseline, scheduled, output_dir)
    using ..BenchmarkFramework
    comparison = compare_results(baseline, scheduled)
    
    improvements = comparison.improvements
    
    println("\nImprovement Summary")
    println("="^70)
    
    metrics = [
        ("Time", improvements["time_improvement_pct"]),
        ("Energy", improvements["energy_savings_pct"]),
        ("Throughput", improvements["throughput_gain_pct"])
    ]
    
    for (metric, value) in metrics
        bar_len = Int(round(abs(value) / 50 * 30))
        bar = value >= 0 ? "█"^bar_len : "▓"^bar_len
        sign = value >= 0 ? "+" : ""
        @printf("  %-12s: %s%6.1f%%  %s\n", metric, sign, value, bar)
    end
    
    @printf("\n  Speedup: %.2fx\n", improvements["speedup"])
    
    # Save summary
    plot_file = joinpath(output_dir, "improvement_summary.txt")
    open(plot_file, "w") do io
        write(io, "# Improvement Summary\n")
        write(io, "Metric,Value\n")
        write(io, @sprintf("Time_Improvement,%.2f\n", improvements["time_improvement_pct"]))
        write(io, @sprintf("Energy_Savings,%.2f\n", improvements["energy_savings_pct"]))
        write(io, @sprintf("Throughput_Gain,%.2f\n", improvements["throughput_gain_pct"]))
        write(io, @sprintf("Speedup,%.3f\n", improvements["speedup"]))
    end
    
    println("  Data saved: $plot_file")
end

function generate_gnuplot_scripts(output_dir)
    # Generate gnuplot script for external plotting
    script_file = joinpath(output_dir, "plot.gnu")
    
    open(script_file, "w") do io
        write(io, """
# Gnuplot script for AutoScheduler benchmarks
# Usage: gnuplot plot.gnu

set terminal png size 1200,800
set output 'comparison.png'
set multiplot layout 2,2

# Time comparison
set title 'Execution Time Comparison'
set ylabel 'Time (seconds)'
set style fill solid
set boxwidth 0.5
plot 'time_comparison.txt' using 1:2 with boxes title 'Baseline', \\
     '' using 1:3 with boxes title 'Scheduled'

# Energy comparison
set title 'Energy Consumption Comparison'
set ylabel 'Energy (Joules)'
plot 'energy_comparison.txt' using 1:2 with boxes title 'Baseline', \\
     '' using 1:3 with boxes title 'Scheduled'

# Distribution
set title 'Execution Time Distribution'
set xlabel 'Sample'
set ylabel 'Time (seconds)'
plot 'distribution.txt' using 1:2 with linespoints title 'Baseline', \\
     '' using 1:3 with linespoints title 'Scheduled'

# Improvements
set title 'Improvement Summary'
set ylabel 'Improvement (%)'
set style histogram clustered
plot 'improvement_summary.txt' using 2:xtic(1) with histogram title 'Improvements'

unset multiplot
""")
    end
    
    println("\nGnuplot script generated: $script_file")
    println("  Run: gnuplot $script_file")
end

function generate_python_plotting_script(output_dir)
    script_file = joinpath(output_dir, "plot.py")
    
    open(script_file, "w") do io
        write(io, """
#!/usr/bin/env python3
# Python plotting script for AutoScheduler benchmarks
# Requires: matplotlib, pandas

import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

# Read data
time_data = pd.read_csv('time_comparison.txt', comment='#')
energy_data = pd.read_csv('energy_comparison.txt', comment='#')
dist_data = pd.read_csv('distribution.txt', comment='#')
improv_data = pd.read_csv('improvement_summary.txt', comment='#')

# Create figure
fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle('AutoScheduler Benchmark Results', fontsize=16)

# Time comparison
ax = axes[0, 0]
categories = ['Baseline', 'Scheduled']
means = [time_data['Baseline_Mean'][0], time_data['Scheduled_Mean'][0]]
stds = [time_data['Baseline_Std'][0], time_data['Scheduled_Std'][0]]
ax.bar(categories, means, yerr=stds, capsize=10)
ax.set_ylabel('Execution Time (s)')
ax.set_title('Time Comparison')
ax.grid(axis='y', alpha=0.3)

# Energy comparison
ax = axes[0, 1]
means = [energy_data['Baseline_Mean'][0], energy_data['Scheduled_Mean'][0]]
stds = [energy_data['Baseline_Std'][0], energy_data['Scheduled_Std'][0]]
ax.bar(categories, means, yerr=stds, capsize=10, color=['#ff7f0e', '#2ca02c'])
ax.set_ylabel('Energy Consumption (J)')
ax.set_title('Energy Comparison')
ax.grid(axis='y', alpha=0.3)

# Distribution
ax = axes[1, 0]
ax.plot(dist_data['Sample'], dist_data['Baseline'], 'o-', label='Baseline')
ax.plot(dist_data['Sample'], dist_data['Scheduled'], 's-', label='Scheduled')
ax.set_xlabel('Sample')
ax.set_ylabel('Time (s)')
ax.set_title('Execution Time Distribution')
ax.legend()
ax.grid(alpha=0.3)

# Improvements
ax = axes[1, 1]
metrics = improv_data['Metric'].tolist()
values = improv_data['Value'].tolist()
colors = ['green' if v > 0 else 'red' for v in values]
ax.barh(metrics, values, color=colors)
ax.set_xlabel('Improvement (%)')
ax.set_title('Improvement Summary')
ax.axvline(x=0, color='black', linestyle='-', linewidth=0.5)
ax.grid(axis='x', alpha=0.3)

plt.tight_layout()
plt.savefig('benchmark_results.png', dpi=300, bbox_inches='tight')
print("Plot saved: benchmark_results.png")
plt.show()
""")
    end
    
    println("Python plotting script generated: $script_file")
    println("  Run: python3 $script_file")
end

# Main function
function main()
    if length(ARGS) < 1
        println("Usage: julia generate_plots.jl RESULT_DIR")
        println("\nExample:")
        println("  julia generate_plots.jl benchmarks/results/20260104_120000")
        exit(1)
    end
    
    result_dir = ARGS[1]
    
    if !isdir(result_dir)
        error("Result directory not found: $result_dir")
    end
    
    # Create plots directory
    plots_dir = joinpath(result_dir, "plots")
    mkpath(plots_dir)
    
    println("Generating plots from: $result_dir")
    println("Output directory: $plots_dir\n")
    println("="^70)
    
    # Load results
    data = load_results(result_dir)
    baseline = data["baseline"]
    scheduled = data["scheduled"]
    
    # Generate plots
    generate_time_comparison_plot(baseline, scheduled, plots_dir)
    generate_energy_comparison_plot(baseline, scheduled, plots_dir)
    generate_distribution_plot(baseline, scheduled, plots_dir)
    generate_improvement_summary(baseline, scheduled, plots_dir)
    
    # Generate external plotting scripts
    generate_gnuplot_scripts(plots_dir)
    generate_python_plotting_script(plots_dir)
    
    println("\n" * "="^70)
    println("✓ Plot generation complete!")
    println("="^70)
    println("\nGenerated files:")
    for file in readdir(plots_dir)
        println("  - $(joinpath(plots_dir, file))")
    end
    
    println("\nTo generate high-quality plots:")
    println("  Option 1: gnuplot $(joinpath(plots_dir, "plot.gnu"))")
    println("  Option 2: python3 $(joinpath(plots_dir, "plot.py"))")
end

# Run main
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end