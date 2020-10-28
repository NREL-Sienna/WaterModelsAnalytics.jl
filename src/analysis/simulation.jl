
"""
Perform EPANET hydraulic simulation (via WNTR) using controls in WM
wm_solution. 
"""
function simulate(wm_data::Dict{String,Any}, wm_solution::Dict{String,Any},
                     inpfilepath::String)

    # populate a wntr network with simulation results
    wn = wntr.network.model.WaterNetworkModel(inpfilepath)

    # store pump names in a set
    pump_set = Set()
    for (key,pump) in wm_solution["solution"]["nw"]["1"]["pump"]
        pump_name = wm_data["nw"]["1"]["pump"][key]["name"] # epanet name
        push!(pump_set, pump_name)
    end

    # store shutoff valve names in a set
    shutoff_valve_set = Set()
    for (key,shutoff_valve) in wm_solution["solution"]["nw"]["1"]["valve"]
        valve_name = wm_data["nw"]["1"]["valve"][key]["name"]
        if string(wm_data["nw"]["1"]["valve"][key]["flow_direction"]) == "UNKNOWN"
            push!(shutoff_valve_set,valve_name)
        end
    end

    # store tank names in a set
    tank_set = Set()
    tank_index_dict = Dict{String,String}()
    for (key,tank) in wm_solution["solution"]["nw"]["1"]["tank"]
        tank_name = wm_data["nw"]["1"]["tank"][key]["name"] # epanet name
        push!(tank_set, tank_name)
        tank_index_dict[tank_name] = key
    end

    # store artificial links and nodes connected to tanks in a Dict
    arti_link_dict = Dict{String,String}()
    arti_node_dict = Dict{String,String}()
    tank_link_dict = Dict{String,Any}()

    for tank_name in tank_set
        tank_link_dict[tank_name] = Set()   # links in the original EPANET file that are connected to the tanks
    end

    # retrieve added artificial nodes and links for tanks
    for (key,valve) in wm_data["nw"]["1"]["valve"]
        artificial_link = wm_data["nw"]["1"]["valve"][key]["name"] # not necessarily an artifical link
        node_to_index = string(wm_data["nw"]["1"]["valve"][key]["node_to"])
        node_fr_index = string(wm_data["nw"]["1"]["valve"][key]["node_fr"])

        if wm_data["nw"]["1"]["node"][node_to_index]["source_id"][2] in tank_set
            tank_name = wm_data["nw"]["1"]["node"][node_to_index]["source_id"][2]
            arti_link_dict[tank_name] = artificial_link
            if wm_data["nw"]["1"]["node"][node_to_index] == tank_index_dict[tank_name]
                artificial_node = wm_data["nw"]["1"]["node"][node_fr_index]["name"]
            else
                artificial_node = wm_data["nw"]["1"]["node"][node_to_index]["name"]
            end
            arti_node_dict[tank_name] = artificial_node
        elseif wm_data["nw"]["1"]["node"][node_fr_index]["source_id"][2] in tank_set
            tank_name = wm_data["nw"]["1"]["node"][node_fr_index]["source_id"][2]
            arti_link_dict[tank_name] = artificial_link
            if wm_data["nw"]["1"]["node"][node_fr_index] == tank_index_dict[tank_name]
                artificial_node = wm_data["nw"]["1"]["node"][node_to_index]["name"]
            else
                artificial_node = wm_data["nw"]["1"]["node"][node_fr_index]["name"]
            end
            arti_node_dict[tank_name] = artificial_node
        end
    end

    link_types = ["pipe", "valve", "pump"]
    for ltype in link_types
        for (key, link) in wm_solution["solution"]["nw"]["1"][ltype]
            link_name = wm_data["nw"]["1"][ltype][key]["name"]
            node_to_index = string(wm_data["nw"]["1"][ltype][key]["node_to"])
            node_fr_index = string(wm_data["nw"]["1"][ltype][key]["node_fr"])

            node_to_name = wm_data["nw"]["1"]["node"][node_to_index]["source_id"][2]
            node_fr_name = wm_data["nw"]["1"]["node"][node_fr_index]["source_id"][2]

            for tank_name in tank_set
                if ((node_to_name == tank_name) & !(node_fr_name == tank_name)) | (!(node_to_name == tank_name) & (node_fr_name == tank_name))
                    if !(link_name == arti_link_dict[tank_name])
                        push!(tank_link_dict[tank_name],link_name)
                    end
                end
            end

        end
    end


    ## add artificial nodes and links to tanks in wn 
    for tank_name in tank_set
        tank_elevation = wn.nodes._data[tank_name].elevation
        diameter = wn.nodes._data[tank_name].diameter

        # enforce the initial levels of tanks 
        wn.nodes._data[tank_name].init_level = wm_solution["solution"]["nw"]["1"]["tank"][tank_index_dict[tank_name]]["V"]/(1/4*pi*diameter^2)

        # add artificial node and link
        wn.add_junction(arti_node_dict[tank_name],base_demand=0,elevation=tank_elevation)
        wn.add_pipe(arti_link_dict[tank_name],start_node_name=arti_node_dict[tank_name],end_node_name=tank_name,
        length=1e-3,diameter=1,roughness=100,minor_loss=0,status="Open",check_valve_flag=false)


        # save information of tank links, re-connect them to artificial nodes
        for link_name in tank_link_dict[tank_name]
            # save link info
            start_node_name = wn.links._data[link_name].start_node_name
            end_node_name = wn.links._data[link_name].end_node_name
            pipe_length = wn.links._data[link_name].length
            diameter = wn.links._data[link_name].diameter
            roughness = wn.links._data[link_name].roughness
            minor_loss = wn.links._data[link_name].minor_loss
            status = wn.links._data[link_name].status
            if status == 1
                status = "Open"
            else
                status = "Closed"
            end
            cv = wn.links._data[link_name].cv 
            # remove link
            wn.remove_link(link_name,with_control=true,force=true)


            # add the link back and connect to the artificial node
            if start_node_name == tank_name
                wn.add_pipe(link_name,start_node_name=arti_node_dict[tank_name],end_node_name=end_node_name,
                    length=pipe_length,diameter=diameter,roughness=roughness,minor_loss=minor_loss,status=status,check_valve_flag=cv)
            else
                wn.add_pipe(link_name,start_node_name=start_node_name,end_node_name=arti_node_dict[tank_name],
                    length=pipe_length,diameter=diameter,roughness=roughness,minor_loss=minor_loss,status=status,check_valve_flag=cv)
            end
        end
    end

 
    # remove old controls
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




    # add new shutoff valve controls
    for tx in 1:length(keys(wm_solution["solution"]["nw"]))
        for (key,shutoff_valve_dict) in wm_solution["solution"]["nw"][string(tx)]["valve"]

            shutoff_valve_name = wm_data["nw"]["1"]["valve"][key]["name"]
            if shutoff_valve_name in shutoff_valve_set


                shutoff_valve_obj = wn.get_link(shutoff_valve_name)
                shutoff_valve_status = shutoff_valve_dict["status"]
                act = wntrctrls.ControlAction(shutoff_valve_obj,"status",shutoff_valve_status)
                cond = wntrctrls.SimTimeCondition(wn, "=",(tx-1)*3600)
                ctrl = wntrctrls.Control(cond,act)
                ctrl_name = join(["Control_",string(shutoff_valve_name),string("_"),string(tx-1)])
                wn.add_control(ctrl_name,ctrl)
            end
        end
    end

    # add new pump controls
    for tx in 1:length(keys(wm_solution["solution"]["nw"]))
        for (key,pump_dict) in wm_solution["solution"]["nw"][string(tx)]["pump"]
            pump_name = wm_data["nw"]["1"]["pump"][key]["name"] # epanet name
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

    println("----- WNTR Simulation Completed -----")
    return wn,wnres

end 
