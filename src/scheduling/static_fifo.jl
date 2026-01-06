module StaticFIFO

using Base.Threads
using ..NonUniformMonteCarlo

export run_fifo

function run_fifo(tasks)
    results = zeros(Float64, length(tasks))
    t_start = time()

    @sync for (i, task) in enumerate(tasks)
        Threads.@spawn begin
            results[i] = execute_task(task)
        end
    end

    elapsed = time() - t_start
    return elapsed
end

end
