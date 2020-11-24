
"""
Perform EPANET hydraulic simulation (via WNTR) using controls in WM
wm_solution. 
"""

function simulate(wm_data::Dict{String,Any}, wm_solution::Dict{String,Any},
                     inpfilepath::String)

    ## initialize a new wntr network
    wn = wntr.network.model.WaterNetworkModel()
    num_time_step = length(wm_solution["solution"]["nw"])
    time_step = wm_data["time_step"]/3600                            # duration per time step (hour)

    wn.options.time.duration = wm_data["duration"]
    wn.options.time.hydraulic_timestep = wm_data["time_step"]
    wn.options.time.quality_timestep = wm_data["time_step"]
    wn.options.time.rule_timestep = wm_data["time_step"]
    wn.options.time.pattern_timestep = wm_data["time_step"]
    wn.options.time.report_timestep = wm_data["time_step"]
    wn.options.time.pattern_start = 0
    wn.options.time.report_start = 0
    wn.options.time.start_clocktime = 0


    ## add reservoir
    added_nodes = Set()     # track node_ids of nodes that are already added to wn
    for (reservoir_id,reservoir_info) in wm_data["nw"]["1"]["reservoir"]
        node_id = string(reservoir_info["node"])

        if haskey(wm_data["nw"]["1"]["node"][node_id],"coordinates")
            coordinates = wm_data["nw"]["1"]["node"][node_id]["coordinates"]
        else
            coordinates = (0,0)
        end

        base_head = 1
        head_pattern = Array{Float64,1}(undef,num_time_step)
        for t in 1:num_time_step
            head_pattern[t] = wm_data["nw"][string(t)]["node"][node_id]["head"]
        end

        wn.add_pattern("res_pat"*node_id, head_pattern)

        wn.add_reservoir(node_id, base_head=base_head, head_pattern="res_pat"*node_id, coordinates=coordinates)
        push!(added_nodes,node_id)
    end





    ## add tank_name
    for (tank_id,tank_info) in wm_data["nw"]["1"]["tank"]
        node_id = string(tank_info["node"])
        elevation = wm_data["nw"]["1"]["node"][node_id]["elevation"]
        init_level = wm_solution["solution"]["nw"]["1"]["node"][node_id]["p"]   # IMPORTANT: WaterModels allows flexible initial tank level!
        min_level = tank_info["min_level"]
        max_level = tank_info["max_level"]
        diameter = tank_info["diameter"]
        min_vol = tank_info["min_vol"]

        if haskey(wm_data["nw"]["1"]["node"][node_id],"coordinates")
            coordinates = wm_data["nw"]["1"]["node"][node_id]["coordinates"]
        else
            coordinates = (0,0)
        end

        wn.add_tank(node_id,elevation=elevation,init_level=init_level,min_level=min_level,max_level=max_level,diameter=diameter,
                    min_vol=min_vol,vol_curve=nothing,overflow=false,coordinates=coordinates)
        push!(added_nodes,node_id)
    end


    ## add demand
    for (demand_id,demand_info) in wm_data["nw"]["1"]["demand"]
        node_id = string(demand_info["node"])
        elevation = wm_data["nw"]["1"]["node"][node_id]["elevation"]

        if haskey(wm_data["nw"]["1"]["node"][node_id],"coordinates")
            coordinates = wm_data["nw"]["1"]["node"][node_id]["coordinates"]
        else
            coordinates = (0,0)
        end

        base_demand = 1
        demand_pattern = Array{Float64,1}(undef,num_time_step)
        for t in 1:num_time_step
            demand_pattern[t] = wm_data["nw"][string(t)]["demand"][demand_id]["flow_rate"]
        end
        wn.add_pattern("dem_pat"*node_id, demand_pattern)
        wn.add_junction(node_id,base_demand=base_demand,demand_pattern="dem_pat"*node_id,elevation=elevation,coordinates=coordinates)
        push!(added_nodes,node_id)
    end


    ## add other nodes
    for (node_id,node_info) in wm_data["nw"]["1"]["node"]
        if node_id in added_nodes
            continue
        else
            elevation = node_info["elevation"]

            if haskey(wm_data["nw"]["1"]["node"][node_id],"coordinates")
            coordinates = wm_data["nw"]["1"]["node"][node_id]["coordinates"]
            else
                coordinates = (0,0)
            end

            wn.add_junction(node_id,base_demand=0,elevation=elevation,coordinates=coordinates)
        end
    end








    ## add pipes
    for (pipe_id,pipe_info) in wm_data["nw"]["1"]["pipe"]
        node_fr = string(pipe_info["node_fr"])
        node_to = string(pipe_info["node_to"])
        length = pipe_info["length"]
        diameter = pipe_info["diameter"]
        roughness = pipe_info["roughness"]
        minor_loss = pipe_info["minor_loss"]
        status = pipe_info["status"]
        if status == 1
            status = "Open"
        else
            status = "Closed"
        end

        wn.add_pipe("pipe"*pipe_id,node_fr,node_to,length=length,diameter=diameter,
                    roughness=roughness,minor_loss=minor_loss,status=status)
    end


    ## add short_pipes
    for (short_pipe_id,short_pipe_info) in wm_data["nw"]["1"]["short_pipe"]
        node_fr = string(short_pipe_info["node_fr"])
        node_to = string(short_pipe_info["node_to"])
        length = 1e-3
        diameter = 1
        roughness = 100
        minor_loss = short_pipe_info["minor_loss"]
        status = "Open"
        wn.add_pipe("short_pipe"*short_pipe_id,node_fr,node_to,length=length,diameter=diameter,
                    roughness=roughness,minor_loss=minor_loss,status=status)
    end


    ## add valves
    for (valve_id,valve_info) in wm_data["nw"]["1"]["valve"]
        node_fr = string(valve_info["node_fr"])
        node_to = string(valve_info["node_to"])
        length = 1e-3
        diameter = 1
        roughness = 100
        minor_loss = 0
        status = "Open"
        if string(valve_info["flow_direction"]) == "UNKNOWN"
            cv_flag = false
        elseif string(valve_info["flow_direction"]) == "POSITIVE"
            cv_flag = true
        end
        wn.add_pipe("valve"*valve_id,node_fr,node_to,length=length,diameter=diameter,
                    roughness=roughness,minor_loss=minor_loss,status=status,check_valve_flag = cv_flag)
    end


    ## add regulators
    # TODO

    ## add pumps
    for (pump_id,pump_info) in wm_data["nw"]["1"]["pump"]
        # add pump with attributes
        node_fr = string(pump_info["node_fr"])
        node_to = string(pump_info["node_to"])
        head_curve = pump_info["head_curve"]
        wn.add_curve("pump_head_curve"*pump_id,"HEAD",head_curve)
        wn.add_pump("pump"*pump_id,node_fr,node_to,pump_type="HEAD",pump_parameter="pump_head_curve"*pump_id,
                    speed=1,pattern=nothing)

        # couple efficiency_curve to the pump
        if haskey(pump_info,"efficiency_curve")
            efficiency_curve = pump_info["efficiency_curve"]
            wn.add_curve("pump_eff_curve"*pump_id,"EFFICIENCY",efficiency_curve)
            wn.get_link("pump"*pump_id).efficiency = wn.get_curve("pump_eff_curve"*pump_id)
        else
            wn.options.energy.global_efficiency = pump_info["efficiency"]
        end
    end


    # add shutoff valve controls 
    for tx in 1:num_time_step
        for (valve_id,shutoff_valve_info) in wm_solution["solution"]["nw"][string(tx)]["valve"]
            if wm_data["nw"]["1"]["valve"][valve_id]["source_id"][1] == "valve"
                shutoff_valve_name = "valve"*valve_id
                shutoff_valve_obj = wn.get_link(shutoff_valve_name)
                shutoff_valve_status = round(shutoff_valve_info["status"])

                if (tx >= 2) && (round(shutoff_valve_status) == round(wm_solution["solution"]["nw"][string(tx-1)]["valve"][valve_id]["status"]))
                    continue    # no change in valve status, no need to add control
                else
                    act = wntrctrls.ControlAction(shutoff_valve_obj,"status",shutoff_valve_status)
                    cond = wntrctrls.SimTimeCondition(wn, "=",(tx-1)*time_step*3600)
                    ctrl = wntrctrls.Control(cond,act)
                    ctrl_name = join(["Valve_control_",string(shutoff_valve_name),string("_"),string(tx-1)])
                    wn.add_control(ctrl_name,ctrl)
                end

            end
        end
    end

    # add pump controls
    for tx in 1:num_time_step
        for (pump_id,pump_info) in wm_solution["solution"]["nw"][string(tx)]["pump"]
            pump_name = "pump"*pump_id
            pump_obj = wn.get_link(pump_name)
            pump_status = round(pump_info["status"])
            if (tx >= 2) && (round(pump_status) == round(wm_solution["solution"]["nw"][string(tx-1)]["pump"][pump_id]["status"]))
                continue    # no change in pump status, no need to add control
            else
                act = wntrctrls.ControlAction(pump_obj,"status",pump_status)
                cond = wntrctrls.SimTimeCondition(wn, "=",(tx-1)*time_step*3600)
                ctrl = wntrctrls.Control(cond,act)
                ctrl_name = join(["Pump_control_",string(pump_name),string("_"),string(tx-1)])
                wn.add_control(ctrl_name,ctrl)
            end
        end
    end

    # run simulation
    wns = wntr.sim.EpanetSimulator(wn)
    path_to_tmp_folder = mktempdir()
    wnres = wns.run_sim(joinpath(path_to_tmp_folder, "epanetfile"))
    rm(path_to_tmp_folder, recursive = true)

    return wn,wnres

end 
