
"""
Compare the fluctuations in tank levels calculated from WaterModels and WNTR
"""

using Plots

function compare_tank_level(wm_data,wm_solution,wntr_data,wntr_simulation, outfilepath::String, tank_id)
    duration = length(wm_solution["solution"]["nw"])    # number of time steps 
    tank_name = wm_data["nw"]["1"]["tank"][tank_id]["source_id"][2]
    diameter = wntr_data.nodes._data[tank_name].diameter
    level_wntr = Array{Float64,1}(undef,duration)
    level_watermodels = Array{Float64,1}(undef,duration)

    for t in 1:duration
        level_wntr[t] = wntr_simulation.node["pressure"][tank_name].values[t]
        level_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["tank"][tank_id]["V"]/(1/4*pi*diameter^2)
    end

    p = plot(1:duration,ones(duration,1).*wntr_data.nodes._data[tank_name].min_level,label="Min level",linecolor=:black,linestyle=:dash)
    p = plot!(p,1:duration,ones(duration,1).*wntr_data.nodes._data[tank_name].max_level,label="Max level",linecolor=:black,linestyle=:dot)
    p = plot!(p,1:duration,level_wntr,label="WNTR",
      title=string(tank_name),xlabel="duration (h)",ylabel="Water level (m)")
    p = plot!(p,1:duration,level_watermodels,label="WaterModel")
    savefig(p,outfilepath*tank_name*".png")
end 
