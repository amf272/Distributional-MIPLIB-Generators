"""
"""
function save_results!(model::JuMP.Model, ref::Dict, D::Int, T::Int, wildfire_risk_per_line::Dict, off_lines::Dict, undergroundable_lines::Dict, load::Dict)
    #may slow down runtime

    #create vector of names for buses, branches, and generators
    bus_names = sort([bus for bus in keys(ref[:bus])])
    branch_names = sort([branch for branch in ref[:arcs_from]])
    gen_names = sort([gen for gen in keys(ref[:gen])])
    
    all_undergroundable_lines = []
    for d in 1:D
        for line in undergroundable_lines[d]
            push!(all_undergroundable_lines, line)
        end
    end
    unique!(all_undergroundable_lines)
    
    #identify the termination status
    #https://www.gurobi.com/documentation/9.1/refman/optimization_status_codes.html
    #termination_status(wildfire_model) == MOI.OPTIMAL
    opt_status = termination_status(model)
    printstyled("Optimization status: $opt_status\n"; color = :yellow, bold=true)
    
    #save optization time
    #returns solve time reported by solver
    opt_solver_time = solve_time(model)
    printstyled("Opt solver time: $opt_solver_time\n"; color = :yellow, bold=true)    
    
    #extract JuMP variables
    va = model[:va]
    load_shedding = model[:load_shedding]

    g = model[:g]
    p = model[:p]
    z = model[:z]
    y = model[:y] #add rest
    aux_max = model[:aux_max]
    
    #create dictionary with solution
    results = Dict("opt_solver_time" => opt_solver_time, "opt_status" => opt_status, "T" => T, "off_lines" => off_lines, "undergroundable_lines" => undergroundable_lines, "load" => load, "wildfire_risk_per_line" => wildfire_risk_per_line)
    
    if results["opt_status"]==OPTIMAL || results["opt_status"]==TIME_LIMIT || results["opt_status"]==LOCALLY_SOLVED
    
        #calculate MIP gap
        MIP_gap = MOI.get(model, MOI.RelativeGap())
        printstyled("MIP_gap: $MIP_gap\n"; color = :yellow, bold=true)
        push!(results, "MIP_gap" => MIP_gap)
        
        #save objective value
        obj = objective_value(model)
        printstyled("obj: $obj\n"; color = :yellow, bold=true)
        push!(results, "obj" => obj)

        #save value of fairness metric
        push!(results, "metric_val" => 0.0)
            
        #save binary variables for undergrounding decisions
        push!(results, "z_orig" => JuMP.value.(z))
        push!(results, "y_orig" => JuMP.value.(y))

        #round the undergrounding decision variables
        push!(results, "z" => results["z_orig"])
        push!(results, "y" => results["y_orig"])
        for d in 1:D
            for i in undergroundable_lines[d]
                results["z"][d,i] = round(results["z"][d,i])
            end 
        end
        for i in all_undergroundable_lines
            results["y"][i] = round(results["y"][i])
        end

        #determine which lines are OFF
        push!(results, "switched_off_lines" => Dict(d => [i for i in undergroundable_lines[d] if results["z"][d,i]==0.0] for d in 1:D))
        
        #determine which lines are undergrounded
        push!(results, "undergrounded_lines" => Dict(d => [i for i in all_undergroundable_lines if results["y"][i]==1.0] for d in 1:D))
        
        #save voltage angle variables 
        push!(results, "va" => JuMP.value.(va))
        
        #save generation variables
        push!(results, "g" => JuMP.value.(g))
        
        #save load_shedding variables
        push!(results, "load_shedding" => JuMP.value.(load_shedding))
        push!(results, "load_shedding_val" => Dict(d => Dict(bus => [results["load_shedding"][d,t,bus] for t in 1:T] for bus in bus_names) for d in 1:D))
        #rewrite to be triple indexed [d][t][bus] ^^^^


        #save power flow variables
        push!(results, "p" => JuMP.value.(p))  
            
        #save the total wildfire risk in network
        push!(results, "total_wildfire_risk" => sum(wildfire_risk_per_line[d][1][i] for d in 1:D for i in keys(ref[:branch])))
        
        #save the daily total wildfire risk across the network
        push!(results, "daily_wildfire_total" => Dict(d => sum(wildfire_risk_per_line[d][1][i] for i in keys(ref[:branch])) for d in 1:D))

        #total non-negative load
        push!(results, "total_nonneg_load" => reduce(+, load[d][t][i][1] for d in 1:D for t in 1:T for i in bus_names if load[d][t][i][1] >=0; init = 0.0))

        #non-negative load shed
        push!(results, "nonneg_load_shed" => sum(results["load_shedding"][d,t,i] for d in 1:D for t in 1:T for i in bus_names if load[d][t][i][1] >=0))

        #wildfire risk removed by turning off lines
        switch_remove = 0.0
        for d in 1:D
            for i in undergroundable_lines[d]
                switch_remove += (1-results["z"][d,i])*wildfire_risk_per_line[d][1][i]
            end
        end
        push!(results, "switched_risk_removed" => switch_remove)
        
        hard_remove = 0.0
        for d in 1:D
            for i in all_undergroundable_lines
                hard_remove += (results["y"][i])*wildfire_risk_per_line[d][1][i]
            end
        end
        push!(results, "hardened_risk_removed" => hard_remove)
        
        #calculate the network risk when lines are switched our and undergrounded lines removed
        push!(results, "wildfire_risk" => results["total_wildfire_risk"] - results["switched_risk_removed"] - results["hardened_risk_removed"])

    else
        
        println(results["opt_status"])
        stat = results["opt_status"]
        error("Optimiztion status not optimal, time limit, or locally solved: $stat")
        
    end
    
    return results

end
