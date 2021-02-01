
"""
Perform EPANET hydraulic simulation (via WNTR) and compute timeseries of flows and heads
"""


function _get_wntr_node_attribute(wntr_simulation, name::AbstractString, attribute::String)
    values = PyCall.getproperty(wntr_simulation.node[attribute], name).values[1:end-1]
    return Float64.(values) # Convert to 64-bit floating point array.
end


function _get_wntr_link_attribute(wntr_simulation, name::AbstractString, attribute::String)
    values = PyCall.getproperty(wntr_simulation.link[attribute], name).values[1:end-1]
    return Float64.(values) # Convert to 64-bit floating point array.
end


# compare nodes
function get_node_dataframe(wm_data, wm_solution, wntr_data, wntr_simulation, node_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"] / 3600.0                        # length per time step (hour)
    node_name = node_id

    head_wntr = _get_wntr_node_attribute(wntr_simulation, node_name, "head")
    pressure_wntr = _get_wntr_node_attribute(wntr_simulation, node_name, "pressure")
    elevation = Array{Float64,1}(undef,num_time_step)
    head_watermodels = Array{Float64,1}(undef,num_time_step)
    pressure_watermodels = Array{Float64,1}(undef,num_time_step)
    
    for t in 1:num_time_step
        elevation[t] = wm_data["nw"][string(t)]["node"][node_id]["elevation"]
        head_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][node_id]["h"]
        pressure_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][node_id]["p"]
    end

    node_df = DataFrames.DataFrame(time = 1:time_step:time_step*num_time_step, elevation = elevation, 
        head_wntr = head_wntr, head_watermodels = head_watermodels,
        pressure_wntr = pressure_wntr, pressure_watermodels = pressure_watermodels)

    return node_df
end

# compare tanks
function get_tank_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation, tank_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    tank_node_id = string(wm_data["nw"]["1"]["tank"][tank_id]["node"])
    tank_name = tank_node_id
    diameter = wntr_data.nodes._data[tank_name].diameter
    volume_wntr = Array{Float64,1}(undef,num_time_step)
    volume_watermodels = Array{Float64,1}(undef,num_time_step)
    level_wntr = Array{Float64,1}(undef,num_time_step)
    level_watermodels = Array{Float64,1}(undef,num_time_step)
    
    volume_wntr = _get_wntr_node_attribute(wntr_simulation, tank_name, "pressure") .* (0.25 * pi * diameter^2)
    level_wntr = _get_wntr_node_attribute(wntr_simulation, tank_name, "pressure")

    for t in 1:num_time_step
        volume_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["tank"][tank_id]["V"]
        level_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][tank_node_id]["p"]
    end

    tank_df = DataFrames.DataFrame(time = 1:time_step:time_step*num_time_step, volume_wntr = volume_wntr, volume_watermodels = volume_watermodels, 
        level_wntr = level_wntr, level_watermodels = level_watermodels)

    return tank_df
end


# compare pipes
function get_pipe_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,pipe_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    pipe_name = "pipe"*pipe_id
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_loss_wntr = Array{Float64,1}(undef,num_time_step)
    head_loss_watermodels = Array{Float64,1}(undef,num_time_step)

    node_fr = string(wm_data["nw"]["1"]["pipe"][pipe_id]["node_fr"])
    node_to = string(wm_data["nw"]["1"]["pipe"][pipe_id]["node_to"])
    flow_wntr = _get_wntr_link_attribute(wntr_simulation, pipe_name, "flowrate")
    head_start_wntr = _get_wntr_node_attribute(wntr_simulation, node_fr, "head")
    head_end_wntr = _get_wntr_node_attribute(wntr_simulation, node_to, "head")
    head_loss_wntr = head_start_wntr .- head_end_wntr

    for t in 1:num_time_step
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["pipe"][pipe_id]["q"]
        head_loss_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][node_fr]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][node_to]["h"]
    end
    
    pipe_df = DataFrames.DataFrame(time = 1:time_step:time_step*num_time_step, flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_loss_wntr = head_loss_wntr, head_loss_watermodels = head_loss_watermodels)

    return pipe_df
end

# compare short pipes
function get_short_pipe_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,short_pipe_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    short_pipe_name = "short_pipe"*short_pipe_id
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_loss_wntr = Array{Float64,1}(undef,num_time_step)
    head_loss_watermodels = Array{Float64,1}(undef,num_time_step)

    node_fr = string(wm_data["nw"]["1"]["short_pipe"][short_pipe_id]["node_fr"])
    node_to = string(wm_data["nw"]["1"]["short_pipe"][short_pipe_id]["node_to"])
    flow_wntr = _get_wntr_link_attribute(wntr_simulation, short_pipe_name, "flowrate")
    head_start_wntr = _get_wntr_node_attribute(wntr_simulation, node_fr, "head")
    head_end_wntr = _get_wntr_node_attribute(wntr_simulation, node_to, "head")
    head_loss_wntr = head_start_wntr .- head_end_wntr

    for t in 1:num_time_step
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["short_pipe"][short_pipe_id]["q"]
        head_loss_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][node_fr]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][node_to]["h"]
    end
    
    short_pipe_df = DataFrames.DataFrame(time = 1:time_step:time_step*num_time_step, flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_loss_wntr = head_loss_wntr, head_loss_watermodels = head_loss_watermodels)

    return short_pipe_df
end

# compare valves
function get_valve_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,valve_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    valve_name = "valve"*valve_id
    status_watermodels = Array{Float64,1}(undef,num_time_step)
    flow_wntr = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_loss_wntr = Array{Float64,1}(undef,num_time_step)
    head_loss_watermodels = Array{Float64,1}(undef,num_time_step)
    node_fr = string(wm_data["nw"]["1"]["valve"][valve_id]["node_fr"])
    node_to = string(wm_data["nw"]["1"]["valve"][valve_id]["node_to"])
    status_wntr = _get_wntr_link_attribute(wntr_simulation, valve_name, "status")
    flow_wntr = _get_wntr_link_attribute(wntr_simulation, valve_name, "flowrate")
    head_start_wntr = _get_wntr_node_attribute(wntr_simulation, node_fr, "head")
    head_end_wntr = _get_wntr_node_attribute(wntr_simulation, node_to, "head")
    head_loss_wntr = head_start_wntr .- head_end_wntr

    for t in 1:num_time_step
        status_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["valve"][valve_id]["status"]
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["valve"][valve_id]["q"]
        head_loss_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["node"][node_fr]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][node_to]["h"]
    end

    valve_df = DataFrames.DataFrame(time = 1:time_step:time_step*num_time_step, status_wntr = status_wntr, status_watermodels = status_watermodels, 
        flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, head_loss_wntr = head_loss_wntr, head_loss_watermodels = head_loss_watermodels)

    return valve_df
end


# compare regulators
# TODO


# compare pumps
function get_pump_dataframe(wm_data,wm_solution,wntr_data,wntr_simulation,pump_id)
    num_time_step = length(wm_solution["solution"]["nw"])            # number of time steps
    time_step = wm_data["time_step"]/3600                            # length per time step (hour)
    pump_name = "pump"*pump_id
    pump_obj = wntr_data.get_link(pump_name)
    status_watermodels = Array{Float64,1}(undef,num_time_step)
    flow_watermodels = Array{Float64,1}(undef,num_time_step)
    head_gain_watermodels = Array{Float64,1}(undef,num_time_step)
    power_wntr = Array{Float64,1}(undef,num_time_step)               # Watt
    power_watermodels = Array{Float64,1}(undef,num_time_step)        # Watt
    cost_wntr = Array{Float64,1}(undef,num_time_step)                # $
    cost_watermodels = Array{Float64,1}(undef,num_time_step)         # $
    node_fr = string(wm_data["nw"]["1"]["pump"][pump_id]["node_fr"])
    node_to = string(wm_data["nw"]["1"]["pump"][pump_id]["node_to"])

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
        power = _WM._GRAVITY * _WM._DENSITY * dh * q / eff # Watt
        return power
    end

    status_wntr = _get_wntr_link_attribute(wntr_simulation, pump_name, "status")
    flow_wntr = _get_wntr_link_attribute(wntr_simulation, pump_name, "flowrate")
    head_start_wntr = _get_wntr_node_attribute(wntr_simulation, node_fr, "head")
    head_end_wntr = _get_wntr_node_attribute(wntr_simulation, node_to, "head")
    head_gain_wntr = status_wntr .* (head_end_wntr .- head_start_wntr)

    for t in 1:num_time_step
        status_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["pump"][pump_id]["status"]
        flow_watermodels[t] = wm_solution["solution"]["nw"][string(t)]["pump"][pump_id]["q"]
        head_gain_watermodels[t] = round(status_watermodels[t])*(wm_solution["solution"]["nw"][string(t)]["node"][node_to]["h"]-wm_solution["solution"]["nw"][string(t)]["node"][node_fr]["h"])
        power_wntr[t] = status_wntr[t]*compute_pump_power(pump_obj,flow_wntr[t],head_gain_wntr[t],wntr_data)
        power_watermodels[t] = status_watermodels[t]*compute_pump_power(pump_obj,flow_watermodels[t],head_gain_watermodels[t],wntr_data)
        energy_price = wm_data["nw"][string(t)]["pump"][pump_id]["energy_price"]*3600    # $/Wh
        cost_wntr[t] = power_wntr[t]*time_step*energy_price
        cost_watermodels[t] = power_watermodels[t]*time_step*energy_price
    end

    pump_df = DataFrames.DataFrame(time = 1:time_step:time_step*num_time_step, status_wntr = status_wntr, status_watermodels = status_watermodels, 
        flow_wntr = flow_wntr, flow_watermodels = flow_watermodels, 
        head_gain_wntr = head_gain_wntr, head_gain_watermodels = head_gain_watermodels,
        power_wntr = power_wntr, power_watermodels = power_watermodels,
        cost_wntr = cost_wntr, cost_watermodels = cost_watermodels)

    return pump_df
end
