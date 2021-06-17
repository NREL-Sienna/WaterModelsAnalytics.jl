@testset "src/analysis/validation.jl" begin
    time_step_h = network_mn["time_step"]/3600

    @testset "compare nodes" begin
	    ## Check 'compare nodes'
	    for (i, node_dict) in network_mn["nw"]["1"]["node"]
            node_id = string(node_dict["name"])
            node_info = network_mn["nw"]["1"]["node"][node_id]
            elevation = node_info["elevation"]
            node_df = get_node_dataframe(network_mn, solution, wntr_network, wntr_result,
                                         node_id)

            ## I encountered this error and hence changed the syntax for all dataframe usage
            ## (JJS 5/10/21):
            #ERROR: ArgumentError: syntax df[column] is not supported use df[!, column] instead
            for t in 1:length(node_df[!, "time"])
                @test check_difference(node_df[!, "time"][t], time_step_h*t, tol)
                @test check_difference(node_df[!, "elevation"][t], elevation, tol)
                wntr_head = getproperty(wntr_result.node["head"], node_id).values[t]
                @test check_difference(node_df[!, "head_wntr"][t], wntr_head, tol)
                @test check_difference(node_df[!, "head_watermodels"][t],
                                       solution["nw"][string(t)]["node"][node_id]["h"], tol)
                wntr_pres = getproperty(wntr_result.node["pressure"], node_id).values[t]
                @test check_difference(node_df[!, "pressure_wntr"][t], wntr_pres, tol)
                @test check_difference(node_df[!, "pressure_watermodels"][t],
                                       solution["nw"][string(t)]["node"][node_id]["p"], tol)
            end
        end
    end
    
    @testset "compare tanks" begin
        ## Check 'compare tanks'
        for (i, tank_dict) in network_mn["nw"]["1"]["tank"]
            tank_id = i
            tank_node_id = string(network_mn["nw"]["1"]["tank"][i]["node"])
            tank_name = tank_node_id
            diameter = wntr_network.nodes._data[tank_name].diameter
            tank_df = get_tank_dataframe(network_mn,solution,wntr_network,wntr_result,
                                         tank_id)
            
            for t in 1:length(tank_df[!, "time"])
                @test check_difference(tank_df[!, "time"][t], time_step_h*t, tol)
                wntr_vol = getproperty(wntr_result.node["pressure"],
                                       tank_name).values[t]*(0.25*pi*diameter^2)
                @test check_difference(tank_df[!, "volume_wntr"][t], wntr_vol, tol)
                @test check_difference(tank_df[!, "volume_watermodels"][t],
                     solution["nw"][string(t)]["node"][tank_name]["p"]*(0.25*pi*diameter^2),
                                       tol)
                wntr_pres = getproperty(wntr_result.node["pressure"], tank_name).values[t]
                @test check_difference(tank_df[!, "level_wntr"][t], wntr_pres, tol)
                @test check_difference(tank_df[!, "level_watermodels"][t],
                                       solution["nw"][string(t)]["node"][tank_name]["p"],
                                       tol)
            end
        end
    end
    
    @testset "compare pipes" begin
        ## check 'compare pipes'
        for (i,pipe_dict) in network_mn["nw"]["1"]["pipe"]
            pipe_id = i
            pipe_name = "pipe"*pipe_id
            node_fr = string(network_mn["nw"]["1"]["pipe"][pipe_id]["node_fr"])
            node_to = string(network_mn["nw"]["1"]["pipe"][pipe_id]["node_to"])
            pipe_df = get_pipe_dataframe(network_mn,solution,wntr_network,wntr_result,
                                         pipe_id)

            for t in 1:length(pipe_df[!, "time"])
                @test check_difference(pipe_df[!, "time"][t], time_step_h*t, tol)
                wntr_flow = getproperty(wntr_result.link["flowrate"], pipe_name).values[t]
                @test check_difference(pipe_df[!, "flow_wntr"][t], wntr_flow, tol)
                @test check_difference(pipe_df[!, "flow_watermodels"][t],
                                       solution["nw"][string(t)]["pipe"][pipe_id]["q"], tol)
                wntr_head_nf = getproperty(wntr_result.node["head"], node_fr).values[t]
                wntr_head_nt = getproperty(wntr_result.node["head"], node_to).values[t]
                @test check_difference(pipe_df[!, "head_loss_wntr"][t],
                                       wntr_head_nf - wntr_head_nt, tol)
                @test check_difference(pipe_df[!, "head_loss_watermodels"][t],
                                       solution["nw"][string(t)]["node"][node_fr]["h"] -
                                       solution["nw"][string(t)]["node"][node_to]["h"], tol)
            end
        end
    
        ## check 'compare shortpipes'
        for (i,short_pipe_dict) in network_mn["nw"]["1"]["short_pipe"]
            short_pipe_id = i
            short_pipe_name = "short_pipe"*short_pipe_id
            node_fr = string(network_mn["nw"]["1"]["short_pipe"][short_pipe_id]["node_fr"])
            node_to = string(network_mn["nw"]["1"]["short_pipe"][short_pipe_id]["node_to"])
            short_pipe_df = get_short_pipe_dataframe(network_mn,solution,wntr_network,
                                                     wntr_result, short_pipe_id)

            for t in 1:length(short_pipe_df[!, "time"])
                @test check_difference(short_pipe_df[!, "time"][t], time_step_h*t, tol)
                wntr_flow = getproperty(wntr_result.link["flowrate"],
                                        short_pipe_name).values[t]
                @test check_difference(short_pipe_df[!, "flow_wntr"][t], wntr_flow, tol)
                @test check_difference(short_pipe_df[!, "flow_watermodels"][t],
                              solution["nw"][string(t)]["short_pipe"][short_pipe_id]["q"],
                                       tol)
                wntr_head_nf = getproperty(wntr_result.node["head"], node_fr).values[t]
                wntr_head_nt = getproperty(wntr_result.node["head"], node_to).values[t]
                @test check_difference(short_pipe_df[!, "head_loss_wntr"][t],
                                       wntr_head_nf - wntr_head_nt, tol)
                @test check_difference(short_pipe_df[!, "head_loss_watermodels"][t],
                                       solution["nw"][string(t)]["node"][node_fr]["h"] -
                                       solution["nw"][string(t)]["node"][node_to]["h"], tol)
            end
        end
    end

    @testset "compare valves" begin
        ## check 'compare valves'
        for (i,valve_dict) in network_mn["nw"]["1"]["valve"]
            valve_id = i
            valve_name = "valve"*valve_id
            node_fr = string(network_mn["nw"]["1"]["valve"][valve_id]["node_fr"])
            node_to = string(network_mn["nw"]["1"]["valve"][valve_id]["node_to"])
            valve_df = get_valve_dataframe(network_mn,solution,wntr_network,wntr_result,
                                           valve_id)

            for t in 1:length(valve_df[!, "time"])
                @test check_difference(valve_df[!, "time"][t], time_step_h*t, tol)
                wntr_st = getproperty(wntr_result.link["status"], valve_name).values[t]
                @test check_difference(valve_df[!, "status_wntr"][t], wntr_st, tol)
                @test check_difference(valve_df[!, "status_watermodels"][t],
                                     solution["nw"][string(t)]["valve"][valve_id]["status"],
                                       tol)
                wntr_flow = getproperty(wntr_result.link["flowrate"], valve_name).values[t]
                @test check_difference(valve_df[!, "flow_wntr"][t], wntr_flow, tol)
                @test check_difference(valve_df[!, "flow_watermodels"][t],
                                       solution["nw"][string(t)]["valve"][valve_id]["q"],
                                       tol)
                wntr_head_nf = getproperty(wntr_result.node["head"], node_fr).values[t]
                wntr_head_nt = getproperty(wntr_result.node["head"], node_to).values[t]
                @test check_difference(valve_df[!, "head_loss_wntr"][t],
                                       wntr_head_nf - wntr_head_nt, tol)
                @test check_difference(valve_df[!, "head_loss_watermodels"][t],
                                       solution["nw"][string(t)]["node"][node_fr]["h"] -
                                       solution["nw"][string(t)]["node"][node_to]["h"], tol)
            end
        end
    end

    @testset "compare pumps" begin
        ## check 'compare pumps'
        function compute_pump_power(pump_obj,q,dh,wntr_data)
            if pump_obj.efficiency == nothing
                eff_curve = nothing
            else
                eff_curve = wntr_data.get_curve(pump_obj.efficiency).points
            end
            if eff_curve != nothing
                for j in 1:length(eff_curve)
                    if (j == 1) & (q < eff_curve[j][1])
                        # use the first Q-eff point when q < q_min on the eff curve
                        eff = eff_curve[j][2]/100
                        break
                    elseif j == length(eff_curve)
                        # use the last Q-eff point when q > q_max on the eff curve
                        eff = eff_curve[j][2]/100 
                    elseif (q >= eff_curve[j][1]) & (q < eff_curve[j+1][1])
                        # linear interpolation of the efficiency curve
                        # why not use Interpolations package? see `plots/pumps.jl`, JJS
                        # 5/13/21
                        a1 = (eff_curve[j+1][1]-q)/(eff_curve[j+1][1]-eff_curve[j][1])
                        a2 = (q-eff_curve[j][1])/(eff_curve[j+1][1]-eff_curve[j][1])
                        eff = (a1*eff_curve[j][2]+a2*eff_curve[j+1][2])/100 
                        break
                    end
                end
            elseif wntr_data.options.energy.global_efficiency != nothing
                 # e.g. convert 60 to 60% (0.6)
                eff = wntr_data.options.energy.global_efficiency/100
            else
                Memento.info(_LOGGER, "No pump efficiency provided, 75% is used")
                eff = 0.75
            end

            power = _WM._GRAVITY * _WM._DENSITY * dh * q / eff # Watt
            return power
        end

        for (i,pump_dict) in network_mn["nw"]["1"]["pump"]
            pump_id = i
            pump_name = "pump"*pump_id
            pump_obj = wntr_network.get_link(pump_name)
            node_fr = string(network_mn["nw"]["1"]["pump"][pump_id]["node_fr"])
            node_to = string(network_mn["nw"]["1"]["pump"][pump_id]["node_to"])
            pump_df = get_pump_dataframe(network_mn,solution,wntr_network,wntr_result,
                                         pump_id)

            for t in 1:length(pump_df[!, "time"])
                @test check_difference(pump_df[!, "time"][t], time_step_h*t, tol)
                wntr_st = getproperty(wntr_result.link["status"], pump_name).values[t]
                @test check_difference(pump_df[!, "status_wntr"][t], wntr_st, tol)
                @test check_difference(pump_df[!, "status_watermodels"][t],
                                       solution["nw"][string(t)]["pump"][pump_id]["status"],
                                       tol)
                wntr_flow = getproperty(wntr_result.link["flowrate"], pump_name).values[t]
                @test check_difference(pump_df[!, "flow_wntr"][t], wntr_flow, tol)
                @test check_difference(pump_df[!, "flow_watermodels"][t],
                                       solution["nw"][string(t)]["pump"][pump_id]["q"], tol)
                wntr_head_nf = getproperty(wntr_result.node["head"], node_fr).values[t]
                wntr_head_nt = getproperty(wntr_result.node["head"], node_to).values[t]
                @test check_difference(pump_df[!, "head_gain_wntr"][t],
                                       wntr_st*(wntr_head_nt - wntr_head_nf), tol)
                @test check_difference(pump_df[!, "head_gain_watermodels"][t],
                                       solution["nw"][string(t)]["pump"][pump_id]["status"]*
                                       (solution["nw"][string(t)]["node"][node_to]["h"]-
                                        solution["nw"][string(t)]["node"][node_fr]["h"]),
                                       tol)
                power_wntr = wntr_st*compute_pump_power(pump_obj, wntr_flow,
                                   wntr_st*(wntr_head_nt - wntr_head_nf), wntr_network)
                power_watermodels = solution["nw"][string(t)]["pump"][pump_id]["status"]*
                compute_pump_power(pump_obj,solution["nw"][string(t)]["pump"][pump_id]["q"],
                                   solution["nw"][string(t)]["pump"][pump_id]["status"]*
                                   (solution["nw"][string(t)]["node"][node_to]["h"] -
                                    solution["nw"][string(t)]["node"][node_fr]["h"]),
                                   wntr_network)
                @test check_difference(pump_df[!, "power_wntr"][t], power_wntr, tol)
                @test check_difference(pump_df[!, "power_watermodels"][t],
                                       power_watermodels, tol)
                energy_price =
                    network_mn["nw"][string(t)]["pump"][pump_id]["energy_price"]*3600 # $/Wh
                @test check_difference(pump_df[!, "cost_wntr"][t],
                                       energy_price*time_step_h*power_wntr,tol)
                @test check_difference(pump_df[!, "cost_watermodels"][t],
                                       energy_price*time_step_h*power_watermodels,tol)
            end
        end
    end        
end
