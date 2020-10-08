
"""
Compare the fluctuations in tank levels calculated from WaterModels and WNTR
"""

using Plots

function compare_tank_head(tank_name::String,wn,wnres,
    node_head_wntr::Dict{String,Any}, node_head_wm::Dict{String,Any}, outfilepath::String)

    duration = 1:length(node_head_wntr[tank_name])
    
	p = plot(duration,ones(length(duration),1).*wn.nodes._data[tank_name].min_level,label="Min level",linecolor=:black,linestyle=:dash)
	p = plot!(p,duration,ones(length(duration),1).*wn.nodes._data[tank_name].max_level,label="Max level",linecolor=:black,linestyle=:dot)
    p = plot!(p,duration,node_head_wntr[tank_name].-wn.nodes._data[tank_name].elevation,label="WNTR",
      title=string(tank_name),xlabel="duration (h)",ylabel="Water level (m)")
    p = plot!(p,duration,node_head_wm[tank_name].-wn.nodes._data[tank_name].elevation,label="WaterModel")

	savefig(p,outfilepath*tank_name*".png")

    println("----- Tank level plot saved -----")
  
    return true

end 
