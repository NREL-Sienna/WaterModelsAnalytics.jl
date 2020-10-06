
"""
Perform EPANET hydraulic simulation (via WNTR) and compute differences in results with WM
solution. 
"""
function epanet_diff(data::Dict{String,Any}, solution::Dict{String,Any},
                     inpfilepath::String)
    
    # populate a wntr network with simulation results
    wn = wntr.network.model.WaterNetworkModel(inpfilepath)

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

    # make the comparisons; just head and flow is done now, should add pump gain, valve
    # status, pump cost -- probably would be good to make these functions

    # head:
    wntr_head = wnnodes["head"]
    head_diffs = Dict{Tuple{String,String},Float64}()

    for tx in 1:length(keys(solution))
        for (key, node) in solution[string(tx)]["node"] 
            node_name = data["node"][key]["source_id"][2]
            if haskey(wntr_head, node_name)
                wntr_head_value = wntr_head[node_name].values[tx]
                head_diffs[node_name,string(tx)] = (node["h"] - wntr_head_value)/max(wntr_head_value, eps(Float32))
            end
        end
    end

    # flow:
    wntr_flow = wnlinks["flowrate"]
    flow_diffs = Dict{Tuple{String,String},Float64}() # if use WM indexing
    link_types = ["pipe", "check_valve", "shutoff_valve", "pump"]
    for tx in 1:length(keys(solution))
        for ltype in link_types
            for (key, link) in solution[string(tx)][ltype]
                if ltype in ["check_valve", "shutoff_valve"]
                    link_name = data["pipe"][key]["name"]
                else
                    link_name = data[ltype][key]["name"]
                end
                if haskey(wntr_flow, link_name)
                    wntr_flow_value = wntr_flow[link_name].values[tx]
                    # using epanet names for the dict for now because unique indexes do not exist in
                    # WM
                    flow_diffs[link_name,string(tx)] = (link["q"] - wntr_flow_value)/max(wntr_flow_value,
                                                                         eps(Float32))
                end
            end
        end
    end







    return head_diffs, flow_diffs

end # funtion epanet_diff
