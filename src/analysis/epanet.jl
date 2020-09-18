
"""
Perform EPANET hydraulic simulation (via WNTR) and compute differences in results with WM
solution. Currently a work-in-progress that analyzes a single timepoint.
"""
function epanet_diff(data::Dict{String,Any}, solution::Dict{String,Any},
                     inpfilepath::String, timepoint)
    
    # populate a wntr network with simulation results
    wn = wntr.network.model.WaterNetworkModel(inpfilepath)
    wn.options.time.duration = 0 # single time-step simulation
    wn.options.time.pattern_start = (timepoint-1)*3600 # test this with different timepoint
    # loop over pumps [and valves, if exist?] to revise wntr network
    for (key,pump) in solution["pump"]
        name = data["pump"][key]["name"] # epanet name
        # create schedule for the time period -- might need to first remove existing
        # controls if they exist
        wnpump = wn."get_link"(name) 
        act = wntrctrls.ControlAction(wnpump, "status", pump["status"])
        cond = wntrctrls.SimTimeCondition(wn, "=", 0) # integer time input is hours
        ctrl = wntrctrls.Control(cond, act)
        ctrlname = name*string(0)
        wn.add_control(ctrlname, ctrl)
    end  

    # WNTR simulation for the single time
    wns = wntr.sim.EpanetSimulator(wn) 
    wnres = wns.run_sim()
    wnlinks = wnres.link
    wnnodes = wnres.node

    # make the comparisons; just head and flow is done now, should add pump gain, valve
    # status, pump cost -- probably would be good to make these functions
    
    # head:
    wntr_head = wnnodes["head"]
    head_diffs = Dict{String,Float64}() # dict to hold relative differences
    for (key, node) in solution["node"]
        #if haskey(nodenames, key)
        #name = nodenames[key] #epanet name -- should be able to get this from data["node"]...
        name = data["node"][key]["source_id"][2]
        if haskey(wntr_head, name)
            wntr_head_value = wntr_head[name].values[1]
            # using epanet names for the dict for now
            head_diffs[name] = (node["h"] - wntr_head_value)/max(wntr_head_value, eps(Float32))
        end
    end

    # flow:
    wntr_flow = wnlinks["flowrate"]
    flow_diffs = Dict{String,Float64}()
    #flow_diffs = Dict{Tuple{String,String},Float64}() # if use WM indexing
    link_types = ["pipe", "check_valve", "shutoff_valve", "pump"]
    for ltype in link_types
        for (key, link) in solution[ltype]
            if ltype in ["check_valve", "shutoff_valve"]
                name = data["pipe"][key]["name"]
            else
                name = data[ltype][key]["name"]
            end
            if haskey(wntr_flow, name)
                wntr_flow_value = wntr_flow[name].values[1]
                # using epanet names for the dict for now because unique indexes do not exist in
                # WM
                flow_diffs[name] = (link["q"] - wntr_flow_value)/max(wntr_flow_value,
                                                                     eps(Float32))
                # if use WM indexing; does work!
                #flow_diffs[(ltype,key)] = (link["q"] - wntr_flow_value)/max(wntr_flow_value, eps(Float32))
            end
        end
    end

    return head_diffs, flow_diffs

end # funtion epanet_diff
