
"""
Perform EPANET hydraulic simulation (via WNTR) and compute timeseries of flows and heads
"""

using DataFrames

# compare nodes
function get_node_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation, node_id)

    duration = length(wm_solution)    # number of time steps 
    node_name = wm_data["node"][node_id]["source_id"][2]

    elevation = Array{Float64,1}(undef,duration)
    head_wntr = Array{Float64,1}(undef,duration)
    head_watermodels = Array{Float64,1}(undef,duration)
    pressure_wntr = Array{Float64,1}(undef,duration)
    pressure_watermodels = Array{Float64,1}(undef,duration)
    
    for t in 1:duration
        elevation[t] = wntr_data.nodes._data[node_name].elevation
        head_wntr[t] = wntr_simulation.node["head"][node_name].values[t]
        head_watermodels[t] = wm_solution[string(t)]["node"][node_id]["h"]
        pressure_wntr[t] = wntr_simulation.node["pressure"][node_name].values[t]
        pressure_watermodels[t] = wm_solution[string(t)]["node"][node_id]["p"]
    end

    node_df = DataFrame(time = 1:1:duration, elevation = vec(elevation), 
        head_wntr = vec(head_wntr), head_watermodels = vec(head_watermodels),
        pressure_wntr = vec(pressure_wntr), pressure_watermodels = vec(pressure_watermodels))

    return node_df
end

# compare tanks
function get_tank_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation, tank_id)
    duration = length(wm_solution)    # number of time steps 
    tank_name = wm_data["tank"][tank_id]["source_id"][2]
    diameter = wntr_data.nodes._data[tank_name].diameter

    volume_wntr = Array{Float64,1}(undef,duration)
    volume_watermodels = Array{Float64,1}(undef,duration)
    level_wntr = Array{Float64,1}(undef,duration)
    level_watermodels = Array{Float64,1}(undef,duration)

    for t in 1:duration
        volume_wntr[t] = wntr_simulation.node["pressure"][tank_name].values[t]*(1/4*pi*diameter^2)
        volume_watermodels[t] = wm_solution[string(t)]["tank"][tank_id]["V"]

        level_wntr[t] = wntr_simulation.node["pressure"][tank_name].values[t]
        level_watermodels[t] = wm_solution[string(t)]["tank"][tank_id]["V"]/(1/4*pi*diameter^2)
    end

    tank_df = DataFrame(time = 1:1:duration, volume_wntr = vec(volume_wntr), volume_watermodels = vec(volume_watermodels), 
        level_wntr = vec(level_wntr), level_watermodels = vec(level_watermodels) )

    return tank_df
end

# compare links
function get_link_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation, link_id)
    if link_id in keys(wm_data["pipe"])
        link_type = "pipe"
    elseif link_id in keys(wm_data["short_pipe"])
        link_type = "short_pipe"
    elseif link_id in keys(wm_data["valve"])
        link_type = "valve"
    else
        link_type = "pump"
    end

    duration = length(wm_solution)
    link_name = wm_data[link_type][link_id]["source_id"][2]
    flow_wntr = Array{Float64,1}(undef,duration)
    flow_watermodels = Array{Float64,1}(undef,duration)
    head_loss_wntr = Array{Float64,1}(undef,duration)
    head_loss_watermodels = Array{Float64,1}(undef,duration)

    for t in 1:duration
        flow_wntr[t] = wntr_simulation.link["flowrate"][link_name].values[t]
        flow_watermodels[t] = wm_solution[string(t)][link_type][link_id]["q"]
        start_node = wntr_data.links._data[link_name].start_node_name
        end_node = wntr_data.links._data[link_name].end_node_name
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node].values[t]-wntr_simulation.node["head"][end_node].values[t]
        head_loss_watermodels[t] = -1*wm_solution[string(t)][link_type][link_id]["dhn"]+wm_solution[string(t)][link_type][link_id]["dhp"]
    end

    link_df = DataFrame(time = 1:1:duration, flow_wntr = vec(flow_wntr), flow_watermodels = vec(flow_watermodels), 
        head_loss_wntr = vec(head_loss_wntr), head_loss_watermodels = vec(head_loss_watermodels) )

    return link_df
end

# compare pipes
function get_pipe_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,pipe_id)

    duration = length(wm_solution)
    pipe_name = wm_data["pipe"][pipe_id]["source_id"][2]
    
    flow_wntr = Array{Float64,1}(undef,duration)
    flow_watermodels = Array{Float64,1}(undef,duration)
    head_loss_wntr = Array{Float64,1}(undef,duration)
    head_loss_watermodels = Array{Float64,1}(undef,duration)

    for t in 1:duration
        flow_wntr[t] = wntr_simulation.link["flowrate"][pipe_name].values[t]
        flow_watermodels[t] = wm_solution[string(t)]["pipe"][pipe_id]["q"]
        start_node = wntr_data.links._data[pipe_name].start_node_name
        end_node = wntr_data.links._data[pipe_name].end_node_name
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node].values[t]-wntr_simulation.node["head"][end_node].values[t]
        head_loss_watermodels[t] = -1*wm_solution[string(t)]["pipe"][pipe_id]["dhn"]+wm_solution[string(t)]["pipe"][pipe_id]["dhp"]
    end
    
    pipe_df = DataFrame(time = 1:1:duration, flow_wntr = vec(flow_wntr), flow_watermodels = vec(flow_watermodels), 
        head_loss_wntr = vec(head_loss_wntr), head_loss_watermodels = vec(head_loss_watermodels) )

    return pipe_df
end

# compare short pipes
function get_short_pipe_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,short_pipe_id)
    duration = length(wm_solution)
    short_pipe_name = wm_data["short_pipe"][short_pipe_id]["source_id"][2]
    flow_wntr = Array{Float64,1}(undef,duration)
    flow_watermodels = Array{Float64,1}(undef,duration)
    head_loss_wntr = Array{Float64,1}(undef,duration)
    head_loss_watermodels = Array{Float64,1}(undef,duration)

    for t in 1:duration
        flow_wntr[t] = wntr_simulation.link["flowrate"][short_pipe_name].values[t]
        flow_watermodels[t] = wm_solution[string(t)]["short_pipe"][short_pipe_id]["q"]
        start_node = wntr_data.links._data[short_pipe_name].start_node_name
        end_node = wntr_data.links._data[short_pipe_name].end_node_name
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node].values[t]-wntr_simulation.node["head"][end_node].values[t]
        head_loss_watermodels[t] = -1*wm_solution[string(t)]["short_pipe"][short_pipe_id]["dhn"]+wm_solution[string(t)]["short_pipe"][short_pipe_id]["dhp"]
    end
    
    short_pipe_df = DataFrame(time = 1:1:duration, flow_wntr = vec(flow_wntr), flow_watermodels = vec(flow_watermodels), 
        head_loss_wntr = vec(head_loss_wntr), head_loss_watermodels = vec(head_loss_watermodels) )

    return short_pipe_df
end

# compare valves
function get_valve_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,valve_id)
    duration = length(wm_solution)
    valve_name = wm_data["valve"][valve_id]["source_id"][2]
    flow_wntr = Array{Float64,1}(undef,duration)
    flow_watermodels = Array{Float64,1}(undef,duration)
    head_loss_wntr = Array{Float64,1}(undef,duration)
    head_loss_watermodels = Array{Float64,1}(undef,duration)

    for t in 1:duration
        flow_wntr[t] = wntr_simulation.link["flowrate"][valve_name].values[t]
        flow_watermodels[t] = wm_solution[string(t)]["valve"][valve_id]["q"]
        start_node = wntr_data.links._data[valve_name].start_node_name
        end_node = wntr_data.links._data[valve_name].end_node_name
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node].values[t]-wntr_simulation.node["head"][end_node].values[t]
        head_loss_watermodels[t] = -1*wm_solution[string(t)]["valve"][valve_id]["dhn"]+wm_solution[string(t)]["valve"][valve_id]["dhp"]
    end
    
    valve_df = DataFrame(time = 1:1:duration, flow_wntr = vec(flow_wntr), flow_watermodels = vec(flow_watermodels), 
        head_loss_wntr = vec(head_loss_wntr), head_loss_watermodels = vec(head_loss_watermodels) )

    return valve_df
end

# compare pumps
function get_pump_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,pump_id)
    duration = length(wm_solution)

    pump_name = wm_data["pump"][pump_id]["source_id"][2]
    pump_obj = wntr_data.get_link(pump_name)
    status = Array{Float64,1}(undef,duration)
    flow_wntr = Array{Float64,1}(undef,duration)
    flow_watermodels = Array{Float64,1}(undef,duration)
    head_gain_wntr = Array{Float64,1}(undef,duration)
    head_gain_watermodels = Array{Float64,1}(undef,duration)
    power_wntr = Array{Float64,1}(undef,duration)
    power_watermodels = Array{Float64,1}(undef,duration)

    function compute_pump_power(pump_obj,q,dh,wntr_data)
        eff_curve = wntr_data.get_curve(pump_obj.efficiency).points
        if eff_curve != nothing
            for j in 1:length(eff_curve)
                if j == length(eff_curve)
                    eff = eff_curve[j][2]/100 # use the last Q-eff point
                elseif (q >= eff_curve[j][1]) & (q < eff_curve[j+1][1])
                    # linear interpolation of the efficiency curve
                    a1 = (eff_curve[j+1][1]-q)/(eff_curve[j+1][1]-eff_curve[j][1])
                    a2 = (q-eff_curve[j][1])/(eff_curve[j+1][1]-eff_curve[j][1])
                    eff = (a1*eff_curve[j][2]+a2*eff_curve[j+1][2])/100 
                    break
                end
            end
        elseif wntr_data.options.energy.global_efficiency != nothing
            eff = wntr_data.options.energy.global_efficiency/100 # e.g. convert 60 to 60% (0.6)
        else
            println("No pump efficiency provided, 75% is used")
            eff = 0.75
        end
        power = 9.81*dh*q/eff # kilowatt (kW)
        return power
    end

    for t in 1:duration
        status[t] = wm_solution[string(t)]["pump"][pump_id]["status"]
        flow_wntr[t] = wntr_simulation.link["flowrate"][pump_name].values[t]
        flow_watermodels[t] = wm_solution[string(t)]["pump"][pump_id]["q"]
        start_node = wntr_data.links._data[pump_name].start_node_name
        end_node = wntr_data.links._data[pump_name].end_node_name
        # the head gain here measures the head difference, not necessarily the lift of an operating pump
        head_gain_wntr[t] = wntr_simulation.node["head"][end_node].values[t]-wntr_simulation.node["head"][start_node].values[t]
        head_gain_watermodels[t] = wm_solution[string(t)]["pump"][pump_id]["dhn"]-wm_solution[string(t)]["pump"][pump_id]["dhp"]

        if status[t] == 0
            power_wntr[t] = 0
            power_watermodels[t] = 0
        else
            power_wntr[t] = compute_pump_power(pump_obj,flow_wntr[t],head_gain_wntr[t],wntr_data)
            power_watermodels[t] = compute_pump_power(pump_obj,flow_watermodels[t],head_gain_watermodels[t],wntr_data)
        end
    end

    pump_df = DataFrame(time = 1:1:duration, status = vec(status), flow_wntr = vec(flow_wntr), flow_watermodels = vec(flow_watermodels), 
        head_gain_wntr = vec(head_gain_wntr), head_gain_watermodels = vec(head_gain_watermodels),
        power_wntr = vec(power_wntr), power_watermodels = vec(power_watermodels) )

    return pump_df
end
