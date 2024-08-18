#=
"""
"""
function categorize_fire_risk_lines(fire_risk_values::Dict, switchable_risk_cutoff::Float64)
    
    #create a vector of the fire potentials in decreasing order (high risk to low risk)
    fire_potential = sort(collect(values(fire_risk_values)), rev=true)
    
    #find the index associated with the cutoff
    switchable_risk_index = findlast(x -> x >= switchable_risk_cutoff, fire_potential)
    
    #calculate the total wildfire risk
    total_wildfire_risk = reduce(+, switchable_risk_index, init = 0.0)
    
    #deterine how many lines in each category
    if isnothing(switchable_risk_index)
        num_low_risk = length(fire_risk_values)
    else
        num_switchable = switchable_risk_index
        num_low_risk = length(fire_risk_values)-switchable_risk_index
    end
    
    #print the number of lines in each category
    #printstyled("Number of switchable lines: $num_switchable\n"; color = :cyan, bold=true)
    #printstyled("Number of low fire risk lines: $num_low_risk\n"; color = :cyan, bold=true)

    #find the line ids in each category
    if isnothing(switchable_risk_index)
        switchable_lines = []
        low_risk_lines = [k for (k,v) in fire_risk_values if v in fire_potential[1:length(fire_risk_values)]]
    else
        switchable_lines = [k for (k,v) in fire_risk_values if v in fire_potential[1:switchable_risk_index]]
        low_risk_lines = [k for (k,v) in fire_risk_values if v in fire_potential[switchable_risk_index+1:length(fire_risk_values)]]
    end

    #plot
    #=
    p1 = plot()
    
    if isnothing(switchable_risk_index)
        plot!(1:length(fire_risk_values), fire_potential[1:length(fire_risk_values)], linewidth = 2, color = :grey, markerstrokecolor = :grey, label = "low risk", markershape = :circle)
    else
        plot!(switchable_risk_index+1:length(fire_risk_values), fire_potential[switchable_risk_index+1:length(fire_risk_values)], linewidth = 2, color = :grey, markerstrokecolor = :grey, label = "low risk", markershape = :circle)
        plot!(1:switchable_risk_index, fire_potential[1:switchable_risk_index], linewidth = 2, color = :red, markerstrokecolor = :red, label = "switchable", markershape = :circle) 
    end
    plot!(annotate = (length(fire_potential)/2, maximum(fire_potential)/2, "switchable=$num_switchable, low=$num_low_risk"))
    plot!(ylabel = "Fire risk")
    #display(p1)
    savefig("risk_lines.svg")
    =#
    
    return switchable_lines, low_risk_lines, total_wildfire_risk
    
end
=#

# used for switchable lines
function categorize_fire_risk_lines(fire_risk_values::Dict, num_switchable_lines)
    
    if num_switchable_lines==0.0
        
        switchable_lines = []
        
    else
    
        #create a vector of the indices correlating to the fire potentials in decreasing order (high risk to low risk)
        indexes_sorted = sortperm(collect(values(fire_risk_values)), rev=true)
        branch_names_sorted = collect(keys(fire_risk_values))[indexes_sorted]

        #extract the top num_switchable_lines branch names
        if length(branch_names_sorted) >= num_switchable_lines
            switchable_lines = branch_names_sorted[1:num_switchable_lines]
            low_risk_lines = branch_names_sorted[num_switchable_lines+1:end]
        else
            switchable_lines = branch_names_sorted
            low_risk_lines = []
        end

        #calculate the number of low risk lines
        num_switchable = length(switchable_lines)
        num_low_risk = length(branch_names_sorted) - length(switchable_lines)

        #print the number of lines in each category
        #printstyled("Number of switchable lines: $num_switchable\n"; color = :cyan, bold=true)
        #printstyled("Number of low fire risk lines: $num_low_risk\n"; color = :cyan, bold=true)
        
    end
    
    #calculate the total wildfire risk
    total_wildfire_risk = sum(collect(values(fire_risk_values)))
    
    return switchable_lines, total_wildfire_risk
    
end

function find_undergroundable_lines(fire_risk_values::Dict, tau_up::Dict, tau_mid::Dict)
    #=
    Purpose: Find the indices for each branch where the fire risk > risk threshold
    Returns: 
        undergroundable_lines: array of indices corresponding to the line
        total_wildfire_risk: total wildfire risk
    =#

    ## define undergroundable lines
    idx_tau = collect(keys(tau_up))
    #tau_upper = tau_up[idx_tau[1]]
    tau_upper = 1.0
    tau_middle = 1e-4
    #tau_middle = tau_mid[idx_tau[1]]
    off_lines = [ind for ind in keys(fire_risk_values) if tau_up[ind] < fire_risk_values[ind]]
    undergroundable_lines = [ind for ind in keys(fire_risk_values) if tau_mid[ind] < fire_risk_values[ind]] #73 bus
    #off_lines = [ind for ind in keys(fire_risk_values) if tau_upper < fire_risk_values[ind]]
    #undergroundable_lines = [ind for ind in keys(fire_risk_values) if tau_middle < fire_risk_values[ind]] #73 bus
    # undergroundable_lines = [ind for ind in keys(fire_risk_values) if tau[ind] < fire_risk_values[ind] <= 247] #WECC

    ##calculate the total wildfire risk
    total_wildfire_risk = sum(collect(values(fire_risk_values)))
    return undergroundable_lines, off_lines, total_wildfire_risk
end
