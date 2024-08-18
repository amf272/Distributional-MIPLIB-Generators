function calculate_line_lengths(ref::Dict, busdata)

    #=
    This function calculates the length of each line based on the long/lat coordinates of each bus
    =#
    #radius of earth in meters
    R = 6371000
    #calculate line lengths
    line_dists = Dict(i => 0.0 for i in collect(keys(ref[:branch])))
    for i in collect(keys(ref[:branch]))
        f_bus = ref[:branch][i]["f_bus"]
        t_bus = ref[:branch][i]["t_bus"]
        lon_1 = busdata.lng[findfirst(isequal(f_bus), busdata.Bus_ID)]
        lat_1 = busdata.lat[findfirst(isequal(f_bus), busdata.Bus_ID)]
        lon_2 = busdata.lng[findfirst(isequal(t_bus), busdata.Bus_ID)]
        lat_2 = busdata.lat[findfirst(isequal(t_bus), busdata.Bus_ID)]
        #convert from degrees to radians
        lat_1_rads = lat_1*pi/180
        lat_2_rads = lat_2*pi/180
        #calculate change in lat and lon between two points
        change_lat = (lat_2-lat_1)*pi/180
        change_lon = (lon_2-lon_1)*pi/180
        #calculate distance in meters
        a = sin(change_lat/2)*sin(change_lat/2) + cos(lat_1_rads)*cos(lat_2_rads)*sin(change_lon/2)*sin(change_lon/2);
        c = 2*atan(sqrt(a), sqrt(1-a));
        dist = R*c*0.0006213712 #meters to miles
        #dist = sqrt((54.6(lon_1-lon_2))^2 + (69*(lat_1-lat_2))^2)
        line_dists[i] = dist
    end
    
    return line_dists
    
end
#=
def calc_dist(lat_1, lon_1, lat_2, lon_2):
    #Calculate distance via haversine formula
    #https://www.movable-type.co.uk/scripts/latlong.html
    #radius of earth in meters
    R = 6371000
    #convert from degrees to radians
    lat_1_rads = lat_1*pi/180
    lat_2_rads = lat_2*pi/180
    #calculate change in lat and lon between two points
    change_lat = (lat_2-lat_1)*pi/180
    change_lon = (lon_2-lon_1)*pi/180
    #calculate distance in meters
    a = sin(change_lat/2)*sin(change_lat/2) + cos(lat_1_rads)*cos(lat_2_rads)*sin(change_lon/2)*sin(change_lon/2);
    c = 2*atan2(sqrt(a), sqrt(1-a));
    dist = R*c
    return dist
=#