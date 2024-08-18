"""
"""
function calc_cost(model::JuMP.Model, ref::Dict, T::Int64)

    #list all generator names
    gen_names = sort([gen for gen in keys(ref[:gen])])
    
    #extract JuMP variables
    g = model[:g]
    if 1 in [ref[:gen][i]["model"] for i in gen_names]
        aux_cost = model[:aux_cost]
    end
    
    #initialize cost to zero
    cost = 0.0
    
    #Print a warning if quadratic cost function
    if maximum([ref[:gen][i]["model"]==2 ? ref[:gen][i]["ncost"] : 0 for i in gen_names])==3
        printstyled("Quadratic polynomial cost model"; color = :cyan, bold=true)
    end

    #cycle through all the time periods
    for t in 1:T
    
        # cycle through all the generators
        for i in gen_names

            # piecewise linear cost model
            if ref[:gen][i]["model"] == 1

                #cost_model ⇒ pg1, f1, pg2, f2, . . . , pgN , fN
                #units of f and p are $/hr and MW (or MVAr), respectively
                #where pg1 < pg2 < · · · < pN and the cost f(pg) is defined by
                #the coordinates (pg1, f1), (pg2, f2), . . . , (pgN , fN )
                #of the end/break-points of the piecewise linear cost

                #extract the break-points for the power and cost values
                x_points = [ref[:gen][i]["cost"][j] for j in 1:2:length(ref[:gen][i]["cost"])] #power
                y_points = [ref[:gen][i]["cost"][j] for j in 2:2:length(ref[:gen][i]["cost"])] #cost

                #check that pg1 == pmin
                if ~(x_points[1] == ref[:gen][i]["pmin"])
                    println(x_points[1])
                    println(ref[:gen][i]["pmin"])
                    error("Smallest piecewise linear cost value does not equal minimum generation value for gen index $i")
                end

                #calculate the slope values
                slope = []
                for j in 1:length(x_points)-1
                    push!(slope, (y_points[j+1] - y_points[j])/(x_points[j+1] - x_points[j]))
                end

                #check that the piecewise linear cost function is convex
                for k in 1:length(slope)-1
                    if slope[k+1]-slope[k] < 0
                        error("Piecewise linear cost function is not convex for gen index $i")
                    end
                end

                # Add constraints on the auxiliary cost variables (http://www.seas.ucla.edu/~vandenbe/ee236a/lectures/pwl.pdf)
                for j in 1:length(slope) #cycle through generators
                    # cost = slope*pg + b
                    @constraint(model, slope[j]*g[t,i] + (y_points[j] - slope[j]*x_points[j]) <= aux_cost[i])                   
                end

                # Minimize the cost of active power generation via the sum of the auxiliary variables
                cost = cost + aux_cost[i]

            # polynomial cost model 
            elseif ref[:gen][i]["model"] == 2

                #(n)th order polynomial 
                n = ref[:gen][i]["ncost"]-1

                #check if the polynomial is more than quadratic
                if n > 2
                   error("Cost model for gen with index $i is not quadratic: n = $n") 
                end

                #cycle through all cost terms
                for j in 1:n+1

                    #N coefficients of n-th order polynomial cost function, starting with highest order
                    #[c_n, c_{n-1}, ..., c_0]
                    #cost = c_n*g^n + · · · + c_1*g + c_0
                    cost += ref[:gen][i]["cost"][j]*g[t,i]^(n+1-j)

                end

            else

                error("Cost model not identified for gen with index $i")

            end

        end
        
    end
    
    return cost
        
end