
"""
Perform EPANET hydraulic simulation (via WNTR) and compute timeseries of flows and heads
"""
function validate(data::Dict{String,Any}, solution::Dict{String,Any},
                     inpfilepath::String, wn, wnres)

    # for each node, compute the head values
    # for each link, compute the flow rates and head gains
    
    wslinks = wnres.link
    wsnodes = wnres.node

    # ------------------------------------------#
    #                   node                    #
    # ------------------------------------------#
    wntr_head = wsnodes["head"]

    node_head_wntr = Dict{String,Any}()
    node_head_wm = Dict{String,Any}()

    for (key, node) in solution["1"]["node"] 
        node_name = data["node"][key]["source_id"][2]
        node_head_wntr[node_name] = Array{Float64,1}(undef,length(solution))
        node_head_wm[node_name] = Array{Float64,1}(undef,length(solution))
    end

    for tx in 1:length(keys(solution))
        for (key, node) in solution[string(tx)]["node"] 
            node_name = data["node"][key]["source_id"][2]
            if haskey(wntr_head, node_name)
                node_head_wntr[node_name][tx] = wntr_head[node_name].values[tx]
                node_head_wm[node_name][tx] = node["h"]
            end
        end
    end



    # ------------------------------------------#
    #                   link                    #
    # ------------------------------------------#
    link_types = ["pipe", "check_valve", "shutoff_valve", "pump"]
    
    wntr_flow = wslinks["flowrate"]
    wntr_dh = wslinks["headloss"]

    link_flow_wntr = Dict{String,Any}()
    link_flow_wm = Dict{String,Any}()

    link_dh_wntr = Dict{String,Any}()   # head gain/loss
    link_dh_wm = Dict{String,Any}()

    for ltype in link_types
        for (key, link) in solution[string("1")][ltype]
            if ltype in ["check_valve", "shutoff_valve"]
                link_name = data["pipe"][key]["name"]
            else
                link_name = data[ltype][key]["name"]
            end
            link_flow_wntr[link_name] = Array{Float64,1}(undef,length(solution))
            link_flow_wm[link_name] = Array{Float64,1}(undef,length(solution))

            link_dh_wntr[link_name] = Array{Float64,1}(undef,length(solution))
            link_dh_wm[link_name] = Array{Float64,1}(undef,length(solution))
        end
    end


    for tx in 1:length(keys(solution))
        for ltype in link_types
            for (key, link) in solution[string(tx)][ltype]
                if ltype in ["check_valve", "shutoff_valve"]
                    link_name = data["pipe"][key]["name"]
                else
                    link_name = data[ltype][key]["name"]
                end
                if haskey(wntr_flow, link_name)
                    link_flow_wntr[link_name][tx] = wntr_flow[link_name].values[tx]
                    link_flow_wm[link_name][tx] = link["q"]

                    link_dh_wntr[link_name][tx] = abs(wntr_dh[link_name].values[tx])
                    link_dh_wm[link_name][tx] = link["dhn"]+link["dhp"]

                end
            end
        end
    end

    # return head_diffs, flow_diffs
    return node_head_wntr,node_head_wm, link_flow_wntr,link_flow_wm, link_dh_wntr,link_dh_wm

end 
