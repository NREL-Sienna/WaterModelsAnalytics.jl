
"""
Perform EPANET hydraulic simulation (via WNTR) and compute timeseries of flows and heads
"""

using DataFrames

# compare nodes
function get_node_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation, node_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    node_name = wm_data["nw"]["1"]["node"][node_id]["source_id"][2]
    
    #  if this is an artificial node added next to a tank, the name should include a prefix
    is_artificial = false
    if wm_data["nw"]["1"]["node"][node_id]["source_id"][1] == "tank"
        is_artificial = true
        for (key,tank) in wm_data["nw"]["1"]["tank"]
            if node_id == string(wm_data["nw"]["1"]["tank"][key]["node"])   # this condition means that the node is the real tank, not the aritificial node next to it
                is_artificial = false
                break
            end
        end
    end
    if is_artificial == true
        node_name = "an"*node_id
    end

    elevation = Array{Float64,1}(undef,num_time_step)
    head_wntr = Array{Float64,1}(undef,num_time_step)
    head_watermodels = Array{Float64,1}(undef,num_time_step)
    pressure_wntr = Array{Float64,1}(undef,num_time_step)
    pressure_watermodels = Array{Float64,1}(undef,num_time_step)
    
    for t in 1:num_time_step
        elevation[t] = elevation[t] = wm_data["nw"][string(t)]["node"][node_id]["elevation"]
        head_wntr[t] = wntr_simulation.node["head"][node_name].values[t]
        head_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][node_id]["h"]
        pressure_wntr[t] = wntr_simulation.node["pressure"][node_name].values[t]
        pressure_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][node_id]["p"]
    end

    node_df = DataFrame(time = 1:time_step:time_step*num_time_step, elevation = elevation, 
        head_wntr = head_wntr, head_watermodels = head_watermodels,
        pressure_wntr = pressure_wntr, pressure_watermodels = pressure_watermodels)

    return node_df
end

# compare tanks
function get_tank_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation, tank_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                       # length per time step (hour)
    tank_name = wm_data["nw"]["1"]["tank"][tank_id]["source_id"][2]
    tank_node_id = string(wm_data["nw"]["1"]["tank"][tank_id]["node"])
    diameter = wntr_data.nodes._data[tank_name].diameter
    volume_wntr = Array{Float64,1}(undef,num_time_step)
    volume_watermodels = Array{Float64,1}(undef,num_time_step)
    level_wntr = Array{Float64,1}(undef,num_time_step)
    level_watermodels = Array{Float64,1}(undef,num_time_step)
    
    for t in 1:num_time_step
        volume_wntr[t] = wntr_simulation.node["pressure"][tank_name].values[t]*(1/4*pi*diameter^2)
        volume_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["tank"][tank_id]["V"]
        level_wntr[t] = wntr_simulation.node["pressure"][tank_name].values[t]
        level_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][tank_node_id]["p"]
    end

    tank_df = DataFrame(time = 1:time_step:time_step*num_time_step, volume_wntr = volume_wntr, volume_watermodels = volume_watermodels, 
        level_wntr = level_wntr, level_watermodels = level_watermodels)

    return tank_df
end

# compare links
function get_link_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation, link_id)
    if link_id in keys(wm_data["nw"]["1"]["pipe"])
        link_type = "pipe"
    elseif link_id in keys(wm_data["nw"]["1"]["short_pipe"])
        link_type = "short_pipe"
    elseif link_id in keys(wm_data["nw"]["1"]["valve"])
        link_type = "valve"
    elseif link_id in keys(wm_data["nw"]["1"]["regulator"])
        link_type = "regulator"
    else
        link_type = "pump"
    end

    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                       # length per time step (hour)
    link_name = wm_data["nw"]["1"][link_type][link_id]["source_id"][2]
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_loss_wntr = Array{Float64,1}(undef,num_time_step)
    head_loss_watermodels = Array{Float64,1}(undef,num_time_step)
    start_node_id = wm_data["nw"]["1"][link_type][link_id]["node_fr"]
    end_node_id = wm_data["nw"]["1"][link_type][link_id]["node_to"]

    # if this is a shutoff valve next to a tank, link_name should include prefix
    for (key,tank) in wm_data["nw"]["1"]["tank"]
        if end_node_id == wm_data["nw"]["1"]["tank"][key]["node"]   # if a link's end node is a tank, this link MUST be an added shutoff valve
            link_name = "al"*link_name
            break
        end
    end

    start_node_name = wntr_data.links._data[link_name].start_node_name
    end_node_name = wntr_data.links._data[link_name].end_node_name

    for t in 1:num_time_step
        flow_wntr[t] = wntr_simulation.link["flowrate"][link_name].values[t]
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)][link_type][link_id]["q"]
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node_name].values[t]-wntr_simulation.node["head"][end_node_name].values[t]
        head_loss_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][string(start_node_id)]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][string(end_node_id)]["h"]
    end

    link_df = DataFrame(time = 1:time_step:time_step*num_time_step, flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_loss_wntr = head_loss_wntr, head_loss_watermodels = head_loss_watermodels)

    return link_df
end

# compare pipes
function get_pipe_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,pipe_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    pipe_name = wm_data["nw"]["1"]["pipe"][pipe_id]["source_id"][2]
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_loss_wntr = Array{Float64,1}(undef,num_time_step)
    head_loss_watermodels = Array{Float64,1}(undef,num_time_step)

    start_node_id = wm_data["nw"]["1"]["pipe"][pipe_id]["node_fr"]
    end_node_id = wm_data["nw"]["1"]["pipe"][pipe_id]["node_to"]
    start_node_name = wntr_data.links._data[pipe_name].start_node_name
    end_node_name = wntr_data.links._data[pipe_name].end_node_name

    for t in 1:num_time_step
        flow_wntr[t] = wntr_simulation.link["flowrate"][pipe_name].values[t]
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["pipe"][pipe_id]["q"]
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node_name].values[t]-wntr_simulation.node["head"][end_node_name].values[t]
        head_loss_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][string(start_node_id)]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][string(end_node_id)]["h"]
    end
    
    pipe_df = DataFrame(time = 1:time_step:time_step*num_time_step, flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_loss_wntr = head_loss_wntr, head_loss_watermodels = head_loss_watermodels)

    return pipe_df
end

# compare short pipes
function get_short_pipe_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,short_pipe_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    short_pipe_name = wm_data["nw"]["1"]["short_pipe"][short_pipe_id]["source_id"][2]
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_loss_wntr = Array{Float64,1}(undef,num_time_step)
    head_loss_watermodels = Array{Float64,1}(undef,num_time_step)

    start_node_id = wm_data["nw"]["1"]["short_pipe"][short_pipe_id]["node_fr"]
    end_node_id = wm_data["nw"]["1"]["short_pipe"][short_pipe_id]["node_to"]
    start_node_name = wntr_data.links._data[short_pipe_name].start_node_name
    end_node_name = wntr_data.links._data[short_pipe_name].end_node_name

    for t in 1:num_time_step
        flow_wntr[t] = wntr_simulation.link["flowrate"][short_pipe_name].values[t]
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["short_pipe"][short_pipe_id]["q"]
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node_name].values[t]-wntr_simulation.node["head"][end_node_name].values[t]
        head_loss_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][string(start_node_id)]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][string(end_node_id)]["h"]
    end
    
    short_pipe_df = DataFrame(time = 1:time_step:time_step*num_time_step, flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_loss_wntr = head_loss_wntr, head_loss_watermodels = head_loss_watermodels)

    return short_pipe_df
end

# compare valves
function get_valve_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,valve_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    valve_name = wm_data["nw"]["1"]["valve"][valve_id]["source_id"][2]
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_loss_wntr = Array{Float64,1}(undef,num_time_step)
    head_loss_watermodels = Array{Float64,1}(undef,num_time_step)
    start_node_id = wm_data["nw"]["1"]["valve"][valve_id]["node_fr"]
    end_node_id = wm_data["nw"]["1"]["valve"][valve_id]["node_to"]

    # if this is a shutoff valve next to a tank, valve_name should include prefix
    for (key,tank) in wm_data["nw"]["1"]["tank"]
        if end_node_id == wm_data["nw"]["1"]["tank"][key]["node"]   # if a link's end node is a tank, this link MUST be an added shutoff valve
            valve_name = "al"*valve_name
            break
        end
    end

    start_node_name = wntr_data.links._data[valve_name].start_node_name
    end_node_name = wntr_data.links._data[valve_name].end_node_name

    for t in 1:num_time_step
        flow_wntr[t] = wntr_simulation.link["flowrate"][valve_name].values[t]
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["valve"][valve_id]["q"]
        start_node = wntr_data.links._data[valve_name].start_node_name
        end_node = wntr_data.links._data[valve_name].end_node_name
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node_name].values[t]-wntr_simulation.node["head"][end_node_name].values[t]
        head_loss_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][string(start_node_id)]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][string(end_node_id)]["h"]
    end

    valve_df = DataFrame(time = 1:time_step:time_step*num_time_step, flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_loss_wntr = head_loss_wntr, head_loss_watermodels = head_loss_watermodels)

    return valve_df
end

# compare regulators
function get_regulator_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,regulator_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    regulator_name = wm_data["nw"]["1"]["regulator"][regulator_id]["source_id"][2]
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_loss_wntr = Array{Float64,1}(undef,num_time_step)
    head_loss_watermodels = Array{Float64,1}(undef,num_time_step)

    start_node_id = wm_data["nw"]["1"]["regulator"][regulator_id]["node_fr"]
    end_node_id = wm_data["nw"]["1"]["regulator"][regulator_id]["node_to"]
    start_node_name = wntr_data.links._data[regulator_name].start_node_name
    end_node_name = wntr_data.links._data[regulator_name].end_node_name

    for t in 1:num_time_step
        flow_wntr[t] = wntr_simulation.link["flowrate"][regulator_name].values[t]
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["regulator"][regulator_id]["q"]
        start_node = wntr_data.links._data[regulator_name].start_node_name
        end_node = wntr_data.links._data[regulator_name].end_node_name
        head_loss_wntr[t] = wntr_simulation.node["head"][start_node_name].values[t]-wntr_simulation.node["head"][end_node_name].values[t]
        head_loss_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][string(start_node_id)]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][string(end_node_id)]["h"]
    end

    regulator_df = DataFrame(time = 1:time_step:time_step*num_time_step, flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_loss_wntr = head_loss_wntr, head_loss_watermodels = head_loss_watermodels)

    return regulator_df
end

# compare pumps
function get_pump_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,pump_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                       # length per time step (hour)
    pump_name = wm_data["nw"]["1"]["pump"][pump_id]["source_id"][2]
    pump_obj = wntr_data.get_link(pump_name)
    status_wntr = Array{Float64,1}(undef,num_time_step)
    status_watermodels = Array{Float64,1}(undef,num_time_step)
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_gain_wntr = Array{Float64,1}(undef,num_time_step)
    head_gain_watermodels = Array{Float64,1}(undef,num_time_step)
    power_wntr = Array{Float64,1}(undef,num_time_step)               # Watt
    power_watermodels = Array{Float64,1}(undef,num_time_step)        # Watt
    cost_wntr = Array{Float64,1}(undef,num_time_step)                # $
    cost_watermodels = Array{Float64,1}(undef,num_time_step)         # $

    start_node_id = wm_data["nw"]["1"]["pump"][pump_id]["node_fr"]
    end_node_id = wm_data["nw"]["1"]["pump"][pump_id]["node_to"]
    start_node_name = wntr_data.links._data[pump_name].start_node_name
    end_node_name = wntr_data.links._data[pump_name].end_node_name

    function compute_pump_power(pump_obj,q,dh,wntr_data)
        if pump_obj.efficiency == nothing
            eff_curve = nothing
        else
            eff_curve = wntr_data.get_curve(pump_obj.efficiency).points
        end
        if eff_curve != nothing
            for j in 1:length(eff_curve)
                if (j == 1) & (q < eff_curve[j][1])
                    eff = eff_curve[j][2]/100 # use the first Q-eff point when q < q_min on the eff curve
                    break
                elseif j == length(eff_curve)
                    eff = eff_curve[j][2]/100 # use the last Q-eff point when q > q_max on the eff curve
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
        power = 9.81*1000*dh*q/eff # Watt
        return power
    end

    for t in 1:num_time_step
        status_wntr[t] = wntr_simulation.link["status"][pump_name].values[t]
        status_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["pump"][pump_id]["status"]
        flow_wntr[t] = wntr_simulation.link["flowrate"][pump_name].values[t]
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["pump"][pump_id]["q"]
        head_gain_wntr[t] = round(status_wntr[t])*(wntr_simulation.node["head"][end_node_name].values[t]-wntr_simulation.node["head"][start_node_name].values[t])
        head_gain_watermodels[t] = round(status_watermodels[t])*(wm_solution["solution"]["nw"][string(t)]["node"][string(end_node_id)]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][string(start_node_id)]["h"])


        power_wntr[t] = status_wntr[t]*compute_pump_power(pump_obj,flow_wntr[t],head_gain_wntr[t],wntr_data)
        power_watermodels[t] = status_watermodels[t]*compute_pump_power(pump_obj,flow_watermodels[t],head_gain_watermodels[t],wntr_data)
        energy_price = wm_data["nw"][string(t)]["pump"][pump_id]["energy_price"]*3600    # $/Wh
        cost_wntr[t] = power_wntr[t]*time_step*energy_price
        cost_watermodels[t] = power_watermodels[t]*time_step*energy_price
        
    end

    pump_df = DataFrame(time = 1:time_step:time_step*num_time_step, status_wntr = status_wntr, status_watermodels = status_watermodels, 
        flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_gain_wntr = head_gain_wntr, head_gain_watermodels = head_gain_watermodels,
        power_wntr = power_wntr, power_watermodels = power_watermodels,
        cost_wntr = cost_wntr, cost_watermodels = cost_watermodels)

    return pump_df
end
