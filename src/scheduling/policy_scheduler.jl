module PolicyScheduler

using Base.Threads
using ..NonUniformMonteCarlo

export PolicyState, run_policy_scheduler

mutable struct PolicyState
    energy_budget::Float64
    deadline::Float64
end

const CPU_POWER_WATTS = 50.0

function estimate_energy(seconds)
    return seconds * CPU_POWER_WATTS
end

function run_policy_scheduler(tasks, policy::PolicyState)
    queue = Channel{MonteCarloTask}(length(tasks))
    for t in tasks
        put!(queue, t)
    end

    t_start = time()

    @sync for _ in 1:Threads.nthreads()
        Threads.@spawn begin
            while isopen(queue)
                task = try
                    take!(queue)
                catch
                    break
                end

                t0 = time()
                execute_task(task)
                elapsed = time() - t0

                energy = estimate_energy(elapsed)

                if time() + elapsed > policy.deadline || policy.energy_budget < energy
                    # defer task
                    put!(queue, task)
                else
                    policy.energy_budget -= energy
                end
            end
        end
    end

    return time() - t_start
end

end
