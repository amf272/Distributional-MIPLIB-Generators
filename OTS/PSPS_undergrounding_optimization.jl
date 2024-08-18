function wildfire_undergrounding_opt(opt_parameters::Dict, load::Dict, D::Int, undergrounding_costs::Dict=Dict(), budget::Float64=0.0, warm_start::Dict=Dict(), time_limit::Float64=86400.0, lp_only::Bool=true; lp_str = "", log_str = "", sol_str = "", ug_dict::Dict=Dict())
    
    #################################################################
    # Set-up Optimization and Parameters
    #################################################################
    
    #identify the ref dictionary
    T = opt_parameters[:T] #number of time periods
    ref = opt_parameters[:ref] #dictionary with network parameters
    off_lines = opt_parameters[:off_lines] #array of undergroundable line names
    switchable_lines = opt_parameters[:undergroundable_lines] #array of undergroundable line names
    threshold = opt_parameters[:network_threshold] #array of undergroundable line names
    obj = opt_parameters[:obj] #type of objective function
    wildfire_risk_per_line = opt_parameters[:wildfire_risk_per_line] #dictionary of wildfire risks
    
    #Initialize Optimization Model
    #---------------------------------------------------------------#
    
    #Create central optimization model
    wildfire_model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(wildfire_model, "MIPGap", 1e-2)
    set_optimizer_attribute(wildfire_model, "Seed", 1)
    MOI.set(wildfire_model, MOI.RawOptimizerAttribute("TimeLimit"), time_limit);
    set_optimizer_attribute(wildfire_model, MOI.Silent(), false)
    set_optimizer_attribute(wildfire_model, "NumericFocus", 3)
    set_optimizer_attribute(wildfire_model, "LogFile", log_str)
    set_optimizer_attribute(wildfire_model, "SolFiles", sol_str)

    #################################################################
    # Optimization Variables
    #################################################################
    
    p_expr = add_variables!(wildfire_model, ref, switchable_lines, D, T, warm_start)
    
    #################################################################
    # Objective Function
    #################################################################
    
    add_objective!(wildfire_model, ref, p_expr, D, T, wildfire_risk_per_line, load)

    #################################################################
    # Optimization Constraints
    #################################################################

    add_DCOPF_constraints!(wildfire_model, ref, p_expr, D, T, load, off_lines, switchable_lines, undergrounding_costs, budget, threshold, wildfire_risk_per_line)

    #################################################################
    #Solve Optimization
    #################################################################
    
    if !(isempty(lp_str))
        JuMP.write_to_file(wildfire_model, lp_str)
    end
    
    results = Dict()
    if !(lp_only)
        optimize!(wildfire_model)

        #################################################################
        #Save Results of Optimization
        ################################################################# 
        results = save_results!(wildfire_model, ref, D, T, wildfire_risk_per_line, off_lines, switchable_lines, load)
        
    end
    return results
    #return results, wildfire_model #, gap, obj_val
    
end
