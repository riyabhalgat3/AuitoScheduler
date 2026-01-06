module ResourceAllocator
using Printf
using Statistics

export allocate_resources, select_best_resource

function allocate_resources(tasks, resources, strategy=:balanced)
    return Dict()
end

function select_best_resource(task, resources, strategy, allocation)
    return nothing
end

end
