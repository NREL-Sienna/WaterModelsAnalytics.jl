function _populate_wntr_time_options!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    # Populate global WNTR time step options.
    wntr_network.options.time.duration = data["duration"]
    wntr_network.options.time.hydraulic_timestep = data["time_step"]
    wntr_network.options.time.quality_timestep = data["time_step"]
    wntr_network.options.time.rule_timestep = data["time_step"]
    wntr_network.options.time.pattern_timestep = data["time_step"]
    wntr_network.options.time.report_timestep = data["time_step"]

    # Populate global WNTR start time options.
    wntr_network.options.time.pattern_start = 0
    wntr_network.options.time.report_start = 0
    wntr_network.options.time.start_clocktime = 0
end


function _populate_wntr_hydraulic_options!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    wntr_network.options.hydraulic.headloss = uppercase(data["head_loss"])
    wntr_network.options.hydraulic.trials = 100
    wntr_network.options.hydraulic.accuracy = 0.001
    wntr_network.options.hydraulic.unbalanced = "CONTINUE"
    wntr_network.options.hydraulic.unbalanced_value = 100
end


function _add_wntr_demands!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    for (i, demand) in data["nw"]["1"]["demand"]
        # Get nodal information associated with the demand.
        node_id = string(demand["node"])
        node = data["nw"]["1"]["node"][node_id]
        elevation = node["elevation"]

        # Prepare metadata for adding the demand.
        coordinates = haskey(node, "coordinates") ? node["coordinates"] : (0.0, 0.0)

        # Prepare the demand head pattern array.
        network_ids = sort([parse(Int, nw) for (nw, nw_data) in data["nw"]])
        pattern = [data["nw"][string(n)]["demand"][i]["flow_nominal"] for n in network_ids]

        # Add the demand flow rate pattern to the WNTR network.
        wntr_network.add_pattern("demand_pattern_" * node_id, pattern)

        # Add the demand to the WNTR network.
        wntr_network.add_junction(
            node_id, base_demand = 1.0, demand_pattern = "demand_pattern_" * node_id,
            elevation = elevation, coordinates = coordinates)
    end
end


function _add_wntr_reservoirs!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    for (i, reservoir) in data["nw"]["1"]["reservoir"]
        # Prepare metadata for adding the reservoir.
        node_id = string(reservoir["node"])
        node = data["nw"]["1"]["node"][node_id]
        coordinates = haskey(node, "coordinates") ? node["coordinates"] : (0.0, 0.0)

        # Prepare the reservoir head pattern array.
        network_ids = sort([parse(Int, nw) for (nw, nw_data) in data["nw"]])
        pattern = [data["nw"][string(n)]["node"][node_id]["head_nominal"] for n in network_ids]

        # Add the reservoir head pattern to the WNTR network.
        wntr_network.add_pattern("reservoir_pattern_" * node_id, pattern)

        # Add the reservoir to the WNTR network.
        wntr_network.add_reservoir(
            node_id, base_head = 1.0, head_pattern = "reservoir_pattern_" * node_id,
            coordinates = coordinates)
    end
end


function _add_wntr_tanks!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    for (i, tank) in data["nw"]["1"]["tank"]
        # Get nodal information associated with the tank.
        node_id = string(tank["node"])
        node = data["nw"]["1"]["node"][node_id]

        # Prepare metadata for adding the tank.
        elevation, init_level = node["elevation"], tank["init_level"]
        min_level, max_level = tank["min_level"], tank["max_level"]
        diameter, min_vol = tank["diameter"], tank["min_vol"]
        coordinates = haskey(node, "coordinates") ? node["coordinates"] : (0.0, 0.0)
        # add original epanet descriptive name of the tank (i.e., source_id)? JJS 7/5/21

        # Add the tank to the WNTR network.
        wntr_network.add_tank(
            node_id, elevation = elevation, init_level = init_level, min_level = min_level,
            max_level = max_level, diameter = diameter, min_vol = min_vol,
            vol_curve = nothing, overflow = false, coordinates = coordinates)
    end
end


function _add_wntr_bare_nodes!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    demand_nodes = [demand["node"] for (i, demand) in data["nw"]["1"]["demand"]]
    tank_nodes = [tank["node"] for (i, tank) in data["nw"]["1"]["tank"]]
    reservoir_nodes = [reservoir["node"] for (i, reservoir) in data["nw"]["1"]["reservoir"]]
    populated_nodes = vcat(demand_nodes, tank_nodes, reservoir_nodes)
    bare_nodes = filter(x -> !(x.second["index"] in populated_nodes), data["nw"]["1"]["node"])

    for (i, node) in bare_nodes
        # Prepare metadata for adding the bare node.
        elevation = node["elevation"]
        coordinates = haskey(node, "coordinates") ? node["coordinates"] : (0.0, 0.0)

        # Add the bare node to the WNTR network.
        wntr_network.add_junction(
            i, base_demand = 0.0, elevation = elevation, coordinates = coordinates)
    end
end


function _add_wntr_pipes!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    for (i, pipe) in data["nw"]["1"]["pipe"]
        node_fr, node_to = string(pipe["node_fr"]), string(pipe["node_to"])
        length, diameter = pipe["length"], pipe["diameter"]
        roughness, minor_loss = pipe["roughness"], pipe["minor_loss"]

        if pipe["status"] == 1
            # Add the pipe to the WNTR network.
            wntr_network.add_pipe(
                "pipe" * i, node_fr, node_to, length = length, diameter = diameter,
                roughness = roughness, minor_loss = minor_loss, status = "Open")
        end
    end
end


function _add_wntr_pumps!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    for (i, pump) in data["nw"]["1"]["pump"]
        if pump["status"] == 1
            # Get pump metadata.
            node_fr, node_to = string(pump["node_fr"]), string(pump["node_to"])

            # Add the pump's head curve as a WNTR curve.
            wntr_network.add_curve("pump_head_curve_" * i, "HEAD", pump["head_curve"])

            # Add the pump to the WNTR network.
            wntr_network.add_pump(
                "pump" * i, node_fr, node_to, pump_type = "HEAD",
                pump_parameter = "pump_head_curve_" * i, speed = 1.0, pattern = nothing)

            # Set the efficiency of the pump in the WNTR network.
            if haskey(pump, "efficiency_curve")
                efficiency_curve = pump["efficiency_curve"]
                wntr_network.add_curve("pump_eff_curve_" * i, "EFFICIENCY", efficiency_curve)
                wntr_efficiency_curve = wntr_network.get_curve("pump_eff_curve_" * i)
                wntr_network.get_link("pump" * i).efficiency = wntr_efficiency_curve
            else
                wntr_network.options.energy.global_efficiency = pump["efficiency"]
            end
        end
    end
end


function _add_wntr_short_pipes!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    for (i, short_pipe) in data["nw"]["1"]["short_pipe"]
        node_fr, node_to = string(short_pipe["node_fr"]), string(short_pipe["node_to"])
        length, diameter = 1.0e-3, 1.0 # Dummy length and diameter.
        roughness, minor_loss = 100.0, short_pipe["minor_loss"]

        if short_pipe["status"] == 1
            # Add the short_pipe to the WNTR network.
            wntr_network.add_pipe(
                "short_pipe" * i, node_fr, node_to, length = length, diameter = diameter,
                roughness = roughness, minor_loss = minor_loss, status = "Open")
        end
    end
end


function _add_wntr_valves!(wntr_network::PyCall.PyObject, data::Dict{String, Any})
    for (i, valve) in data["nw"]["1"]["valve"]
        node_fr, node_to = string(valve["node_fr"]), string(valve["node_to"])
        length, diameter = 1.0e-3, 1.0 # Dummy length and diameter.
        roughness, minor_loss = 100.0, valve["minor_loss"]
        check_valve_flag = string(valve["flow_direction"]) == "POSITIVE"

        if valve["status"] == 1
            # Add the valve to the WNTR network.
            wntr_network.add_pipe(
                "valve" * i, node_fr, node_to, length = length, diameter = diameter,
                roughness = roughness, minor_loss = minor_loss, status = "Open",
                check_valve_flag = check_valve_flag)
        end
    end
end


function _clear_wntr_controls(wntr_network::PyCall.PyObject)
    for i in 1:length(wntr_network.control_name_list)
        wntr_network.remove_control(wntr_network.control_name_list[1])
    end
end


function _set_wntr_tank_level(wntr_network::PyCall.PyObject, data::Dict{String, Any}, solution::Dict{String, Any})
    for (i, tank) in solution["nw"]["1"]["tank"]
        tank_node_name = string(data["nw"]["1"]["tank"][i]["node"])
        wntr_tank = wntr_network.get_node(tank_node_name)
        wntr_tank.init_level = solution["nw"]["1"]["node"][tank_node_name]["p"]
    end
end


function _set_wntr_valve_controls(wntr_network::PyCall.PyObject, data::Dict{String, Any}, solution::Dict{String, Any}, time_step::Float64)
    network_ids = sort([parse(Int, nw) for (nw, nw_sol) in solution["nw"]])

    for (n, nw) in enumerate(network_ids)
        for (i, valve) in solution["nw"][string(nw)]["valve"]
            if data["nw"][string(nw)]["valve"][i]["flow_direction"] == _WM.UNKNOWN
                wntr_valve_name = "valve" * i
                wntr_valve = wntr_network.get_link(wntr_valve_name)
                valve_status = round(valve["status"])

                nw_previous = n == 1 ? string(nw) : string(network_ids[n - 1])
                valve_status_previous = round(solution["nw"][nw_previous]["valve"][i]["status"])

                if n > 1 && valve_status == valve_status_previous
                    continue # No change in valve status, no need to add control.
                else
                    # Define control name and time metadata.
                    control_name_prefix = join(["valve_control_", string(wntr_valve_name)])
                    control_name = join([control_name_prefix, string("_"), string(n - 1)])
                    control_time = (n - 1) * time_step # Time to apply action.

                    # Define the action, condition, and add the control.
                    action = wntrctrls.ControlAction(wntr_valve, "status", valve_status)
                    condition = wntrctrls.SimTimeCondition(wntr_network, "=", control_time)
                    control = wntrctrls.Control(condition, action)
                    wntr_network.add_control(control_name, control)
                end
            end
        end
    end
end


function _set_wntr_pump_controls(wntr_network::PyCall.PyObject, data::Dict{String, Any}, solution::Dict{String, Any}, time_step::Float64)
    network_ids = sort([parse(Int, nw) for (nw, nw_sol) in solution["nw"]])

    for (n, nw) in enumerate(network_ids)
        for (i, pump) in solution["nw"][string(nw)]["pump"]
            wntr_pump_name = "pump" * i
            wntr_pump = wntr_network.get_link(wntr_pump_name)
            pump_status = round(pump["status"])

            nw_previous = n == 1 ? string(nw) : string(network_ids[n - 1])
            pump_status_previous = round(solution["nw"][nw_previous]["pump"][i]["status"])

            if n > 1 && pump_status == pump_status_previous
                continue # No change in pump status, no need to add control.
            else
                # Define control name and time metadata.
                control_name_prefix = join(["pump_control_", string(wntr_pump_name)])
                control_name = join([control_name_prefix, string("_"), string(n - 1)])
                control_time = (n - 1) * time_step # Time to apply action.

                # Define the action, condition, and add the control.
                action = wntrctrls.ControlAction(wntr_pump, "status", pump_status)
                condition = wntrctrls.SimTimeCondition(wntr_network, "=", control_time)
                control = wntrctrls.Control(condition, action)
                wntr_network.add_control(control_name, control)
            end
        end
    end
end


"""
Initialize WNTR network from a WaterModels `data` dictionary.
"""
function initialize_wntr_network(data::Dict{String, Any})
    # Initialize a new WNTR network.
    wntr_network = wntr.network.model.WaterNetworkModel()
    _populate_wntr_time_options!(wntr_network, data)
    _populate_wntr_hydraulic_options!(wntr_network, data)

    # Add nodal components to the network.
    _add_wntr_demands!(wntr_network, data)
    _add_wntr_reservoirs!(wntr_network, data)
    _add_wntr_tanks!(wntr_network, data)
    _add_wntr_bare_nodes!(wntr_network, data)

    # Add node-connecting components to the network.
    _add_wntr_pipes!(wntr_network, data)
    _add_wntr_pumps!(wntr_network, data)
    _add_wntr_short_pipes!(wntr_network, data)
    _add_wntr_valves!(wntr_network, data)

    # Return the final WNTR network object.
    return wntr_network
end


function _get_valve_statuses(wntr_result::PyCall.PyObject, data::Dict{String, Any}, solution::Dict{String, Any})
    network_ids = sort([parse(Int, nw) for (nw, nw_sol) in solution["nw"]])

    for (n, nw) in enumerate(network_ids)
        for (i, valve) in solution["nw"][string(nw)]["valve"]
            if data["nw"]["1"]["valve"][i]["source_id"][1] == "valve"
                wntr_valve_name = "valve" * i
                wntr_valve = wntr_network.get_link(wntr_valve_name)
                valve_status = round(valve["status"])
            end
        end
    end
end


"""
Update `wntr_network` controls from a WaterModels `result` with a time step `time_step`.
"""
function update_wntr_controls(wntr_network::PyCall.PyObject, data::Dict{String, Any}, solution::Dict{String, Any}, time_step::Float64)
    _clear_wntr_controls(wntr_network)
    _set_wntr_tank_level(wntr_network, data, solution)
    _set_wntr_pump_controls(wntr_network, data, solution, time_step)
    _set_wntr_valve_controls(wntr_network, data, solution, time_step)
end


"""
Perform EPANET hydraulic simulation (via WNTR) using controls from `solution`.
"""
function simulate_wntr(wntr_network::PyCall.PyObject)
    wntr_simulator = wntr.sim.EpanetSimulator(wntr_network)
    path_to_tmp_directory = mktempdir()
    wntr_result = wntr_simulator.run_sim(joinpath(path_to_tmp_directory, "epanetfile"))
    rm(path_to_tmp_directory, recursive = true) # Clean up temporary files.
    return wntr_result # Return the WNTR result object.
end
