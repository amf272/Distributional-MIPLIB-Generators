function add_variables!(model::JuMP.Model, ref::Dict, switchable_lines::Dict, D::Int, T::Int, warm_start::Dict=Dict())

    #create vector of names for buses, branches, and generators
    bus_names = sort([bus for bus in keys(ref[:bus])])
    branch_names = sort([branch for branch in ref[:arcs_from]])
    gen_names = sort([gen for gen in keys(ref[:gen])])
    
    #load shed variable
    @variable(model, load_shedding[1:D, 1:T, bus_names] >= 0.0)
    
    #voltage angles
    @variable(model, -pi <= va[1:D, 1:T, bus_names] <= pi)

    #power generation
    g_lb = Containers.DenseAxisArray{Float64}(undef, 1:D, 1:T, gen_names)
    g_ub = Containers.DenseAxisArray{Float64}(undef, 1:D, 1:T, gen_names)
    for d in 1:D
        for t in 1:T
            for i in gen_names
                g_lb[d,t,i] = 0.0 #ref[:gen][i]["pmin"]
                g_ub[d,t,i] = ref[:gen][i]["pmax"]
            end
        end
    end
    @variable(model, g_lb[d,t,i] <= g[d = 1:D, t = 1:T, i = gen_names] <= g_ub[d,t,i])

    #Add power flow variable for each branch
    p_lb = Containers.DenseAxisArray{Float64}(undef, 1:D, 1:T, branch_names)
    p_ub = Containers.DenseAxisArray{Float64}(undef, 1:D, 1:T, branch_names)
    for d in 1:D
        for t in 1:T
            for (l,i,j) in branch_names
                p_lb[d,t,(l,i,j)] = -ref[:branch][l]["rate_a"]
                p_ub[d,t,(l,i,j)] = ref[:branch][l]["rate_a"]
            end
        end
    end
    @variable(model, p_lb[d,t,branch] <= p[d=1:D, t = 1:T, branch = branch_names] <= p_ub[d,t,branch])
    #@variable(model, p[1:D, 1:T, branch_names])

    #Force p[t,(l,i,j)] = -p[t,(l,j,i)], where l=branch id, i and j are "to" and "from" buses
    #power flow in one direction is equal to the negative of the other since there are no losses
    p_expr = Dict((d,t,(l,i,j)) => 1.0*p[d,t,(l,i,j)] for d in 1:D for t in 1:T for (l,i,j) in branch_names)
    p_expr = merge(p_expr, Dict((d, t,(l,j,i)) => -1.0*p[d, t,(l,i,j)] for d in 1:D for t in 1:T for (l,i,j) in branch_names))
    
    #binary variables for energization
    @variable(model, z[d in 1:D, i in switchable_lines[d]], binary=true) #why only undergroundable_lines?
    
    #binary variables for if a line is undergrounded
    all_undergroundable_lines = []
    for d in 1:D
        for line in switchable_lines[d]
            push!(all_undergroundable_lines, line)
        end
    end
    unique!(all_undergroundable_lines)
    
    @variable(model, y[i in all_undergroundable_lines], binary=true) 
    
    #auxillary variable for min maxing load shed across racial groups - not used in baseline undergrounding
    @variable(model, aux_max >= 0.0)

    if ~isempty(warm_start)
        for d in 1:D
            for l in switchable_lines[d]
                set_start_value(z[d,l], warm_start["z"][d,l])
            end
        end
        for l in all_undergroundable_lines                
            set_start_value(y[l], warm_start["y"][l])
        end
    end
    
    return p_expr
    
end
