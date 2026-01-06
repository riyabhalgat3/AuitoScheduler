using AutoScheduler.NonUniformMonteCarlo
using AutoScheduler.StaticFIFO
using AutoScheduler.PolicyScheduler
using AutoScheduler.SchedulerMetrics
using Base.Threads

println("Threads: ", Threads.nthreads())

TOTAL_SAMPLES = 10_000_000
CHUNK_SIZE = 50_000

tasks = generate_tasks(TOTAL_SAMPLES, CHUNK_SIZE)

println("Number of tasks: ", length(tasks))

# Baseline
fifo_time = run_fifo(tasks)

# Policy scheduler
policy = PolicyState(
    energy_budget = 40.0,           # Joules
    deadline = time() + 1.0         # seconds
)

policy_time = run_policy_scheduler(tasks, policy)

println()
println("RESULTS")
println("----------------------------")
println("FIFO time:     ", fifo_time)
println("Policy time:   ", policy_time)
println("Energy left:   ", policy.energy_budget)
