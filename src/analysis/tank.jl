
"""
Compare the fluctuations in tank levels calculated from WaterModels and WNTR
"""

using Plots

function plot_tank_diff(data::Dict{String,Any}, solution::Dict{String,Any},
                     inpfilepath::String, outfilepath::String)
	
	# populate a wntr network with simulation results
    wn = wntr.network.model.WaterNetworkModel(inpfilepath)
    # wn.options.time.duration = length(keys(solution))*3600 

    # store pump names in a set
    pump_set = Set()
    for (key,pump) in solution["1"]["pump"]
        pump_name = data["pump"][key]["name"] # epanet name
        push!(pump_set, pump_name)
    end

    # remove old controlsß
    old_controls = wn.control_name_list
    index_to_remove = 1
    for i = 1:length(old_controls)
        current_control = wn.get_control(old_controls[i])
        control_target = string(current_control._then_actions[1]._target_obj._link_name)
        if !(control_target in pump_set)   # only remove old pump controls
            index_to_remove += 1
        else
            wn.remove_control(wn.control_name_list[index_to_remove]) # remove one by one
        end
    end

    # add new controls
    for tx in 1:length(keys(solution))
        for (key,pump_dict) in solution[string(tx)]["pump"]

            pump_name = data["pump"][key]["name"] # epanet name
            pump_obj = wn.get_link(pump_name)
            pump_status = pump_dict["status"]
            act = wntrctrls.ControlAction(pump_obj,"status",pump_status)
            cond = wntrctrls.SimTimeCondition(wn, "=",(tx-1)*3600)
            ctrl = wntrctrls.Control(cond,act)
            ctrl_name = join(["Control_",string(pump_name),string("_"),string(tx-1)])
            wn.add_control(ctrl_name,ctrl)
        end
    end

    # WNTR simulation 
    wns = wntr.sim.EpanetSimulator(wn)
    wnres = wns.run_sim()
    wnlinks = wnres.link
    wnnodes = wnres.node

    # store tank names in a set
    tank_set = Set()
    for (key,tank) in solution["1"]["tank"]
        tank_name = data["tank"][key]["name"] # epanet name
        push!(tank_set, tank_name)
    end

    tank_level_wntr = Dict{String,Array{Float64,1}}()
    tank_level_wm = Dict{String,Array{Float64,1}}()

    for tank_name in tank_set
    	tank_level_wntr[tank_name] = Array{Float64,1}(undef,length(solution))
    	tank_level_wm[tank_name] = Array{Float64,1}(undef,length(solution))
    end

    wntr_pressure = wnnodes["pressure"]
    for tx in 1:length(keys(solution))
        for (key,tank_dict) in solution[string(tx)]["tank"]

            tank_name = data["tank"][key]["name"] # epanet name

            wntr_tank_level_value = wntr_pressure[tank_name].values[tx]
            wm_tank_level_value = tank_dict["V"]/(0.25*pi*data["tank"][key]["diameter"]^2)

            tank_level_wntr[tank_name][tx] = wntr_tank_level_value
            tank_level_wm[tank_name][tx] = wm_tank_level_value
        end
    end

    time = 1:length(keys(solution))
    for (key,tank_dict) in solution["1"]["tank"]
    	tank_name = data["tank"][key]["name"]
    	p = plot(time,ones(length(time),1).*data["tank"][key]["min_level"],label="Min level",linecolor=:black,linestyle=:dash)
    	p = plot!(p,time,ones(length(time),1).*data["tank"][key]["max_level"],label="Max level",linecolor=:black,linestyle=:dot)
    	p = plot!(p,time,tank_level_wntr[tank_name],label="WNTR",
    		title=string(tank_name),xlabel="Time (h)",ylabel="Water level (m)")
    	p = plot!(p,time,tank_level_wm[tank_name],label="WaterModel")
    	savefig(p,outfilepath*tank_name*".png")
    end

    return true

end 
