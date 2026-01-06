module SchedulerMetrics

using Statistics

export summarize

function summarize(times::Vector{Float64})
    return Dict(
        "mean" => mean(times),
        "p95" => quantile(times, 0.95),
        "p99" => quantile(times, 0.99),
        "max" => maximum(times)
    )
end

end
