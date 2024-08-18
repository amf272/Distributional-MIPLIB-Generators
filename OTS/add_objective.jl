"""
"""
function add_objective!(model::JuMP.Model, ref::Dict, p_expr, D::Int, T::Int, wildfire_risk_per_line::Dict, load::Dict)

    #create vector of names for buses, branches, and generators
    bus_names = sort([bus for bus in keys(ref[:bus])])
    branch_names = sort([branch for branch in ref[:arcs_from]])
    gen_names = sort([gen for gen in keys(ref[:gen])])
    
    #extract JuMP variables
    va = model[:va]
    load_shedding = model[:load_shedding]

    g = model[:g]
    p = model[:p]
    z = model[:z] #binary var; 1 if a line is energized
    y = model[:y]
    aux_max = model[:aux_max]

    #total non-negative load in network
    total_nonneg_load = reduce(+, load[d][t][i][1] for d in 1:D for t in 1:T for i in bus_names if load[d][t][i][1] >=0; init = 0.0)
  
    #non-negative load shedding
    nonneg_loadshed = reduce(+, load_shedding[d, t, i] for d in 1:D for t in 1:T for i in bus_names if load[d][t][i][1] >=0; init = 0.0)

    @objective(model, Min, nonneg_loadshed) 
    
end