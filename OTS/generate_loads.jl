"""
"""

function generate_loads(ref, year, month, day)

    ####-------------Generate tables of multiplication factors-------------####
    
    #Table 1 - Hourly load 
        #          winter weeks      summer weeks     spring/fall weeks
        #         1 -8 & 44 - 52        18 -30         9-17 & 31 - 43
        # Hour     Wkdy     Wknd     Wkdy     Wknd     Wkdy     Wknd
        # -------------------------------------------------------------
    hourly_loads = (1/100).*[67       78       64       74       63       75; # 12-1 am
                    63       72       60       70       62       73; # 1-2
                    60       68       58       66       60       69; # 2-3
                    59       66       56       65       58       66; # 3-4
                    59       64       56       64       59       65; # 4-5
                    60       65       58       62       65       65; # 5-6
                    74       66       64       62       72       68; # 6-7
                    86       70       76       66       85       74; # 7-8
                    95       80       87       81       95       83; # 8-9
                    96       88       95       86       99       89; # 9-10
                    96       90       99       91      100       92; # 10-11
                    95       91      100       93       99       94; # 11-noon
                    95       90       99       93       93       91; # Noon-1pm
                    95       88      100       92       92       90; # 1-2
                    93       87      100       91       90       90; # 2-3
                    94       87       97       91       88       86; # 3-4
                    99       91       96       92       90       85; # 4-5
                   100      100       96       94       92       88; # 5-6
                   100       99       93       95       96       92; # 6-7
                    96       97       92       95       98      100; # 7-8
                    91       94       92      100       96       97; # 8-9
                    83       92       93       93       90       95; # 9-10
                    73       87       87       88       80       90; # 10-11
                    63       81       72       80       70       85  # 11-12
                    ]

    #Table 2 - Weekly Peak Load in Percent of Annual Peak
    #Week Peak Load
    weeklyLoads = (1/100).*[
            1     86.2;
            2     90.0;
            3     87.8;
            4     83.4;
            5     88.0;
            6     84.1;
            7     83.2;
            8     80.6;
            9     74.0;
            10    73.7;
            11    71.5;
            12    72.7;
            13    70.4;
            14    75.0;
            15    72.1;
            16    80.0;
            17    75.4;
            18    83.7;
            19    87.0;
            20    88.0;
            21    85.6;
            22    81.1;
            23    90.0;
            24    88.7;
            25    89.6;
            26    86.1;
            27    75.5;
            28    81.6;
            29    80.1;
            30    88.0;
            31    72.2;
            32    77.6;
            33    80.0;
            34    72.9;
            35    72.6;
            36    70.5;
            37    78.0;
            38    69.5;
            39    72.4;
            40    72.4;
            41    74.3;
            42    74.4;
            43    80.0;
            44    88.1;
            45    88.5;
            46    90.9;
            47    94.0;
            48    89.0;
            49    94.2;
            50    97.0;
            51   100.0;
            52    95.2
            ]

    #Table 3 - Daily load in Percent of Weekly Peak 
    # Peak Load Day
    dailyLoads = (1/100).*[93; # Monday
                 100; # Tuesday
                  98; # Wednesday
                  96; # Thursday
                  94; # Friday
                  77; # Saturday
                  75  # Sunday
                  ]
   
    ####-------------Calculate load multiplication factor-------------####
    
    #define the date
    date = Date(Dates.Year(year),Dates.Month(month),Dates.Day(day))

    #find the day of the week: Monday=1 --> Sunday=7
    dayofweek = Dates.dayofweek(date)

    #find the number of weeks
    weeknumber = Dates.week(date)

    #find the hourly loads
    if weeknumber in vcat(collect(1:8), collect(44:52)) #winter

        if dayofweek in [6,7] #weekend
            hourlycol = 2
        else #weekday
            hourlycol = 1
        end

    elseif weeknumber in collect(18:30) #summer

        if dayofweek in [6,7] #weekend
            hourlycol = 4
        else #weekday
            hourlycol = 3
        end

    elseif weeknumber in vcat(collect(9:17), collect(31:43)) #spring and fall

        if dayofweek in [6,7] #weekend
            hourlycol = 6
        else #weekday
            hourlycol = 5
        end

    end

    #multiple all load factors
    load_mult_factor = hourly_loads[:,hourlycol].*dailyLoads[dayofweek].*weeklyLoads[weeknumber,2]
    
    ####-------------Calculate load multiplication factor-------------####
    
    bus_names = sort([bus for bus in keys(ref[:bus])])
    load = Dict(i => Array{Float64,1}() for i in bus_names)
    
    for i in bus_names
        sum_of_loads = reduce(+, ref[:load][j]["pd"] for j in ref[:bus_loads][i]; init = 0.0)
        load[i] = sum_of_loads.*load_mult_factor
    end
    
    return load
    
end