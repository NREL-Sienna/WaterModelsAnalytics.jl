# in future versions, let's use the dataframe functions and then plot from the dataframe,
# JJS 11/2/20

using Plots

"""
Compare the fluctuations in tank levels calculated from WaterModels and WNTR
"""
function compare_tank_level(wm_data,wm_solution,wntr_data,wntr_simulation, outfilepath::String, tank_id)
    num_time_step = length(wm_solution["solution"]["nw"])    # number of time steps 
    tank_name = wm_data["nw"]["1"]["tank"][tank_id]["source_id"][2]
    tank_node_id = string(wm_data["nw"]["1"]["tank"][tank_id]["node"])
    diameter = wntr_data.nodes._data[tank_name].diameter
    level_wntr = Array{Float64,1}(undef,num_time_step)
    level_watermodels = Array{Float64,1}(undef,num_time_step)
    
    for t in 1:num_time_step
        level_wntr[t] = wntr_simulation.node["pressure"][tank_name].values[t]
        level_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][tank_node_id]["p"]
    end

    p = plot(1:num_time_step,ones(num_time_step,1).*wntr_data.nodes._data[tank_name].min_level,label="Min level",linecolor=:black,linestyle=:dash)
    p = plot!(p,1:num_time_step,ones(num_time_step,1).*wntr_data.nodes._data[tank_name].max_level,label="Max level",linecolor=:black,linestyle=:dot)
    p = plot!(p,1:num_time_step,level_wntr,label="WNTR",
      title=string(tank_name),xlabel="num_time_step (h)",ylabel="Water level (m)")
    p = plot!(p,1:num_time_step,level_watermodels,label="WaterModel")
    savefig(p,outfilepath*tank_name*".png")
end 
