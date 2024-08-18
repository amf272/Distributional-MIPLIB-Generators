"""
"""
function add_DCOPF_constraints!(model::JuMP.Model, ref::Dict, p_expr, D::Int, T::Int, load::Dict, off_lines::Dict, undergroundable_lines::Dict, undergrounding_costs::Dict, budget::Float64, threshold::Float64, wildfire_risk_per_line::Dict, vm_pcts::Dict=Dict(), vm_base::String="none", vm_type::String="none", ls_base_dict::Dict=Dict(); set_results::Dict=Dict(), set_ug::Dict=Dict())
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
    
    #extract JuMP variables
    va = model[:va]
    load_shedding = model[:load_shedding]
    g = model[:g]
    p = model[:p]
    z = model[:z]
    y = model[:y]
    aux_max = model[:aux_max]
    
    @constraint(model, aux_max >= 0.0)
    
    # Multi-time-period DCOPF Constraints
    #---------------------------------------------------------------#
    
    #Force the voltage angles of the reference buses to be 0
    for d in 1:D
        for t in 1:T
            for i in keys(ref[:ref_buses])
                @constraint(model, va[d, t, i] == 0)
            end
        end
    end
    
    #Set load shedding upper and lower limits
    for d in 1:D
        for t in 1:T 
            for i in bus_names
                if load[d][t][i][1] >= 0 #if the load is positive, the load can be shed
                    #create lower constraint
                    @constraint(model, 0 <= load_shedding[d, t, i])
                    #create upper constraint
                    @constraint(model, load_shedding[d, t, i] <= load[d][t][i][1])
                else #if the load is negative, the load cannot be shed
                    error("No negative loads allowed.")
                    @constraint(model, 0 == load_shedding[d, t, i])
                end
            end
        end
    end
    
    #ensure that budget constraint is satisfied when undergrounding lines
    @constraint(model, budget_con, sum(undergrounding_costs[l]*y[l] for l in all_undergroundable_lines) <= budget)
        
    #identify big M constraint
    vad_max = 2*pi
    vad_min = -2*pi
    
    total_wildfire_risk = []
    hardened_risk_removed = []
    switched_risk_removed = []

    #cycle through all the branches and time periods
    for d in 1:D
        #calc total wildfire risk across lines for the day
        push!(total_wildfire_risk, sum(wildfire_risk_per_line[d][1][i] for i in keys(ref[:branch])))
        
        #calc risk removed by undergrounding lines
        push!(hardened_risk_removed, sum(y[i]*wildfire_risk_per_line[d][1][i] for i in all_undergroundable_lines))
        
        #calc risk removed by switching off lines
        push!(switched_risk_removed, sum((1-z[d,i])*wildfire_risk_per_line[d][1][i] for i in undergroundable_lines[d]))
        
        @constraint(model, total_wildfire_risk[d] - (hardened_risk_removed[d] + switched_risk_removed[d]) <= threshold)
        for t in 1:T
            for (l,i,j) in branch_names
                #identify the voltage angles at the "from bus" and "to bus"
                va_fr = va[d,t,i]
                va_to = va[d,t,j]

                #Compute the branch parameters and transformer ratios from the data
                g1, b1 = PowerModels.calc_branch_y(ref[:branch][l])

                #check if branch l is a high_risk line
                if l in off_lines[d]
                    
                    #if line is undergrounded, then it is energized
                    #if line is NOT undergrounded (when it is above risk threshold), then it is de-energized
                    if isempty(set_results)
                        @constraint(model, y[l] == z[d,l]) 
                    end
                    
                    #Restrict power flow to be within long term rating (rate A)
                    #if z=0 --> p^2 <= 0 --> p=0  
                    @constraint(model, -ref[:branch][l]["rate_a"]*z[d,l] <= p[d, t, (l,i,j)])
                    @constraint(model, p[d, t, (l,i,j)] <= ref[:branch][l]["rate_a"]*z[d,l])

                    #DC power flow constraint: p == -b1*(va_fr - va_to)
                    #Relax equality constraint when z=0 using big M forumulation
                    #when z=0 --> -b1*vad_min <= p + b1*(va_fr - va_to) <= -b1*vadmax
                    @constraint(model, p[d, t, (l,i,j)] <= -b1*(va_fr - va_to) + abs(b1)*(vad_max*(1-z[d,l])) )
                    @constraint(model, p[d, t, (l,i,j)] >= -b1*(va_fr - va_to) + abs(b1)*(vad_min*(1-z[d,l])) )

                    #Voltage angle difference limit: angmin <= va_fr - va_to <= angmax
                    #Relax equality constraint when z=0 using big M forumulation
                    #when z=0 --> angmin + vadmin <= va_fr - va_to <= angmax + vadmax
                    @constraint(model, va_fr - va_to <= ref[:branch][l]["angmax"] + vad_max*(1-z[d,l]))
                    @constraint(model, va_fr - va_to >= ref[:branch][l]["angmin"] + vad_min*(1-z[d,l]))
                    
                #check if branch l is a medium-risk line
                elseif l in undergroundable_lines[d]

                    #if line is undergrounded, then it is energized
                    #if line is NOT undergrounded (when it is above risk threshold), then it is de-energized
                    if isempty(set_results)
                        @constraint(model, (1-z[d,l]) + y[l] <= 1)
                    end
                    
                    #Restrict power flow to be within long term rating (rate A)
                    #if z=0 --> p^2 <= 0 --> p=0  
                    @constraint(model, -ref[:branch][l]["rate_a"]*z[d,l] <= p[d, t, (l,i,j)])
                    @constraint(model, p[d, t, (l,i,j)] <= ref[:branch][l]["rate_a"]*z[d,l])

                    #DC power flow constraint: p == -b1*(va_fr - va_to)
                    #Relax equality constraint when z=0 using big M forumulation
                    #when z=0 --> -b1*vad_min <= p + b1*(va_fr - va_to) <= -b1*vadmax
                    @constraint(model, p[d, t, (l,i,j)] <= -b1*(va_fr - va_to) + abs(b1)*(vad_max*(1-z[d,l])) )
                    @constraint(model, p[d, t, (l,i,j)] >= -b1*(va_fr - va_to) + abs(b1)*(vad_min*(1-z[d,l])) )

                    #Voltage angle difference limit: angmin <= va_fr - va_to <= angmax
                    #Relax equality constraint when z=0 using big M forumulation
                    #when z=0 --> angmin + vadmin <= va_fr - va_to <= angmax + vadmax
                    @constraint(model, va_fr - va_to <= ref[:branch][l]["angmax"] + vad_max*(1-z[d,l]))
                    @constraint(model, va_fr - va_to >= ref[:branch][l]["angmin"] + vad_min*(1-z[d,l]))
                    
                else #for low-risk lines
                    #Voltage angle difference limit: angmin <= va_fr - va_to <= angmax
                    @constraint(model, va_fr - va_to <= ref[:branch][l]["angmax"])
                    @constraint(model, va_fr - va_to >= ref[:branch][l]["angmin"])
                        
                    #DC power flow constraint: p == -b1*(va_fr - va_to)
                    @constraint(model, p[d, t, (l,i,j)] == -b1*(va_fr - va_to))
                end
            end
        end
    end
    
    #Bus power balance constraints
    for d in 1:D 
        for t in 1:T
            for k in bus_names
                #power balance, where power flow i is zero if z[i]=0
                @constraint(model, 
                    sum(p_expr[(d,t,(l,i,j))] for (l,i,j) in ref[:bus_arcs][k]) #sum of active power flows from bus i
                    == sum(g[d,t,m] for m in ref[:bus_gens][k]) #sum of active power generations at bus i
                    - load[d][t][k][1] #sum of active power demands at bus k
                    + load_shedding[d,t,k] #load shedding at bus k
                    )
                
                        
            end
        end
    end
end