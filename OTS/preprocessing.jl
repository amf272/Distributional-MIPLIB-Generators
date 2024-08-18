#=
To Do:
-Need to be able to compute P_l, which is the cost of undergrounding each line, l
=#

function preprocessing(model_name::String, network_data::Dict, year::Int, month_start::Int, day_start::Int, month_end::Int, day_end::Int, T::Int, tau_up::Dict, tau_mid::Dict, network_threshold::Float64)
    
    ####-------------Create ref and indices dictionary-------------####

    #delete lower gen limits, set to 0
    for i in keys(network_data["gen"])
        network_data["gen"][i]["pmin"] = 0.0    
    end
    
    #create reference dictionary
    ref = PowerModels.build_ref(network_data)[:it][:pm][:nw][0]
    
    ### ----- Fix infinity issue ----- ### 
    #####################################################################################
    branch_data = [PowerModels.calc_branch_y(ref[:branch][l]) for l in keys(ref[:branch])]
    max_b = maximum([abs(j) for (i,j) in branch_data])
    #g almost always positve, b almost always negative

    max_angle = maximum([ref[:branch][l]["angmax"] for l in keys(ref[:branch])])

    #if any line does not have a flow limit, add one
    for i in keys(ref[:branch])
        if ~haskey(ref[:branch][i], "rate_a")
            push!(ref[:branch][i], "rate_a" => 10*max_b*max_angle)
        end
    end
    
    ####-------------Determine the days in the simulation-------------####
    
    #calculate number of days in 
    start_date = Date(year, month_start, day_start)
    end_date = Date(year, month_end, day_end)
    num_days = Dates.value(end_date - start_date) + 1   
    
    ####-------------Create dictionary of wildfire risks-------------####
    
    #create array of branch names
    branch_names = sort([branch for branch in keys(ref[:branch])])


    #### -------------- Used for RTS, not for WECC ----------------- ####
    #import the 2019 and 2020 risk values
    # risks_2019 = load(string("data/USGS_FPI/RTS/risks_RTS_2019.jld2"))["2019"] #array of dictionaries
    # risks_2020 = load(string("data/USGS_FPI/RTS/risks_RTS_2020.jld2"))["2020"]

    # #create vectors of sum of risks per day from 2019 and 2020
    # sum_risks_2019 = [sum(risks_2019[j][i] for i in branch_names) for j in 1:length(risks_2019)]
    # sum_risks_2020 = [sum(risks_2020[j][i] for i in branch_names) for j in 1:length(risks_2020)]

    # #calcualte the max and min sum of risks
    # max_risk = maximum(vcat(sum_risks_2019, sum_risks_2020))
    # min_risk = minimum(vcat(sum_risks_2019, sum_risks_2020))
    # avg_risk = mean(vcat(sum_risks_2019, sum_risks_2020))
    # range_risk = max_risk - min_risk
    #######################################################################
    
    
    #### -------------- WECC or Texas --------------------------------- ####
    #import the 2019 and 2020 risk values
    #risks_2019 = load(string("/storage/coda1/p-dmolzahn6/0/rpiansky3/data/USGS_FPI/reduced/$model_name/2019/forecast_day_1/FPI_$(model_name)_fday1_year2019_month$(month_start)_day$(day_start).jld2"))["FPI_$(model_name)_fday1_year2019_month$(month_start)_day$(day_start)"]["high_risk_line_int"]
    #risks_2020 = load(string("/storage/coda1/p-dmolzahn6/0/rpiansky3/data/USGS_FPI/reduced/$(model_name)/2020/forecast_day_1/FPI_$(model_name)_fday1_year2020_month$(month_start)_day$(day_start).jld2"))["FPI_$(model_name)_fday1_year2020_month$(month_start)_day$(day_start)"]["high_risk_line_int"]
    ########################################################################

    
    # #calculate the range of alpha values

    # #initialize wildfire data
    wildfire_risk_per_line = Dict()
    
    #cycle through the number of days
    for i in 1:num_days
        
        #identify the consdiered day
        day_1_forecast = start_date + Dates.Day(i-1)
        
        #create temp dictionary to store wildfire risk
        temp_forecast = Dict()

        #identify the forecast date
        forecast_date = day_1_forecast # + Dates.Day(j-1)
        forecast_year = Dates.year(forecast_date)
        forecast_month = Dates.month(forecast_date)
        forecast_day = Dates.day(forecast_date)

        ###load the wildfire risk
        ##WECC or Texas
        j = 1
        f_day_risk = load(string("/project/dilkina_438/weiminhu/miplib/generator_ryan/lp_generator/data/USGS_FPI/reduced/", "$model_name", "/", "$forecast_year", "/", "forecast_day_", "$j", "/", "FPI_", "$model_name", "_fday", "$j", "_year", "$forecast_year", "_month", "$forecast_month", "_day", "$forecast_day", ".jld2"))[string("FPI_", "$model_name", "_fday", "$j", "_year", "$forecast_year", "_month", "$forecast_month", "_day", "$forecast_day")][ "high_risk_line_int"]

        #add risk to dictionary
        push!(temp_forecast, j => f_day_risk)
            
        
        push!(wildfire_risk_per_line, i => temp_forecast)
        map!(x->x/1000000, values(wildfire_risk_per_line[i][1]))
    end
    
    
    ####-------------Create dictionary of "actual" multi-time-period loads-------------####
    
    ### May want to change this "actual" data in the future
    #import the CAISO data
    load_data_6 = DataFrame(CSV.File("data/CAISO_data/HistoricalEMSHourlyLoadforJune2021.csv"))
    load_data_7 = DataFrame(CSV.File("data/CAISO_data/HistoricalEMSHourlyLoadforJuly2021.csv"))
    load_data_8 = DataFrame(CSV.File("data/CAISO_data/HistoricalEMSHourlyLoadforAugust2021.csv"))
    load_data_9 = DataFrame(CSV.File("data/CAISO_data/HistoricalEMSHourlyLoadforSeptember2021.csv"))
    load_data_10 = DataFrame(CSV.File("data/CAISO_data/HistoricalEMSHourlyLoadforOctober2021.csv"))
    load_data_11 = DataFrame(CSV.File("data/CAISO_data/HistoricalEMSHourlyLoadforNovember2021.csv"))
    CAISO_data = vcat(load_data_6, load_data_7, load_data_8, load_data_9, load_data_10, load_data_11)
    
    #determine the maximum load from the CAISO data
    max_load = maximum(CAISO_data.CAISO)
    
    #calculate the loads at the buses in the nominal, single-time-period case
    bus_names = sort([bus for bus in keys(ref[:bus])])
    sum_of_loads = Dict(i => reduce(+, ref[:load][j]["pd"] for j in ref[:bus_loads][i]; init = 0.0) for i in bus_names)

    #initialize dictionary of loads
    #actual_load_dict[day in wildfire season][forecast day number][bus][vector of loads per hour]
    actual_load_dict = Dict()

    #cycle through the number of days
    for i in 1:num_days

        #identify the consdiered day
        forecast_date = start_date + Dates.Day(i-1)
        forecast_year = Dates.year(forecast_date)
        forecast_month = Dates.month(forecast_date)
        forecast_day = Dates.day(forecast_date)

        #calculate the fraction of the max load for each time period
        CAISO_load_frac = [CAISO_data[(CAISO_data.Date .== string("$forecast_month", "/", "$forecast_day", "/", "$forecast_year")) .& (CAISO_data.HR .== t), :].CAISO[1] for t in 1:T]./max_load

        #check that the length of the vector is 24
        if ~(length(CAISO_load_frac)==T)
            println(length(CAISO_load_frac))
            error("Length of CAISO_load_frac vector is not 24.")
        end

        if sum(CAISO_load_frac .< 0) > 0
            error("Negative loads")
        end
        
        #initialize temp dictionary
        temp_loads = Dict(bus => Array{Float64,1}() for bus in bus_names)

        #cycle through all the buses
        for bus in bus_names
            temp_load = sum_of_loads[bus].*CAISO_load_frac.*rand(Uniform(0.95,1.05),1,1)[1]
            if temp_load[1] <= 1e-4
                temp_load[1] = 0
            end
            push!(temp_loads, bus => temp_load)
        end
        temp_day = Dict(1 => temp_loads)

        push!(actual_load_dict, i => temp_day)

    end
    
    ####-------------Create dictionary of predicted multi-time-period loads-------------####
    #=
    #initialize dictionary of loads
    predicted_load_dict = Dict()

    #cycle through the number of days
    for i in 1:num_days

        #identify the consdiered day
        day_1_forecast = start_date + Dates.Day(i-1)

        #create temp dictionary
        temp_forecast = Dict()

        #cycle through the days in the forecast horizon
        for j in 1:forecast_horizon
        #for j in 1:1

            #identify the forecast date
            forecast_date = day_1_forecast + Dates.Day(j-1)
            forecast_year = Dates.year(forecast_date)
            forecast_month = Dates.month(forecast_date)
            forecast_day = Dates.day(forecast_date)

            #calculate the fraction of the max load for each time period
            CAISO_load_frac = [CAISO_data[(CAISO_data.Date .== string("$forecast_month", "/", "$forecast_day", "/", "$forecast_year")) .& (CAISO_data.HR .== t), :].CAISO[1] for t in 1:T]./max_load

            #check that the length of the vector is 24
            if ~(length(CAISO_load_frac)==T)
                println(length(CAISO_load_frac))
                error("Length of CAISO_load_frac vector is not 24.")
            end

            if sum(CAISO_load_frac .< 0) > 0
                error("Negative loads")
            end
            
            #purturb demand values using uniform distribution
            scaled_demand = rand(Uniform(1-demand_forecast_error[j], 1+demand_forecast_error[j]), length(bus_names), T)
            
            if sum(sum(scaled_demand .< 0)) > 0
                error("Negative scaled_demand")
            end

            #initialize temp dictionary
            temp_loads = Dict(bus => Array{Float64,1}() for bus in bus_names)

            #cycle through all the buses
            count = 0
            for bus in bus_names
                count = count + 1
                push!(temp_loads, bus => sum_of_loads[bus].*CAISO_load_frac.*scaled_demand[count,:])
            end

            #save values
            push!(temp_forecast, j => temp_loads)

        end

        push!(predicted_load_dict, i => temp_forecast)

    end
    =#
    ####-------------Find undergroundable lines-------------####
    
    #categorize the lines based on wildfire risk
    undergroundable_lines = Dict()
    off_lines = Dict()
    total_wildfire_risk = Dict()
    
    #cycle through the number of days
    for i in 1:num_days
    
        #identify the considered day
        day_1_forecast = start_date + Dates.Day(i-1)
        
        undergroundable_lines_temp, off_lines_temp, total_wildfire_risk_temp = find_undergroundable_lines(wildfire_risk_per_line[i][1], tau_up, tau_mid)
        
        undergroundable_lines[i] = undergroundable_lines_temp
        off_lines[i] = off_lines_temp
        total_wildfire_risk[i] = total_wildfire_risk_temp
        
    end
    
    ####-------------Create dictionary of optimization parameters-------------####
    
    opt_parameters = Dict()
    push!(opt_parameters, 
        :T => T,
        :ref => ref,
        :off_lines => off_lines,
        :undergroundable_lines => undergroundable_lines,
        :actual_load => actual_load_dict,
        :obj => obj,
        :wildfire_risk_per_line => wildfire_risk_per_line,
        :network_threshold => network_threshold,
        :total_wildfire_risk => total_wildfire_risk
    )
    
    return opt_parameters
    
end
