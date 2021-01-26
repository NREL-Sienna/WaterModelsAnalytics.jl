import Gurobi
import JSON
import JuMP
using WaterModels
using PyCall


@testset "src/analysis/simulation.jl" begin

	## input the tolerance for mismatch
	tol = 1e-2
	function check_difference(a,b,tol)
		return abs((a-b)/(a+b+1e-7)) <= tol
	end
	
	## Parse the network data
	network = parse_file("../test/data/epanet/multinetwork/Richmond_skeleton.inp")
	network_mn = WaterModels._IM.make_multinetwork(network, WaterModels._wm_global_keys);

	data = network_mn
	network_ids = sort([parse(Int, nw) for (nw, nw_data) in data["nw"]])

	# ## Solve the pump scheduling problem
	# env = Gurobi.Env(); # Initialize a common Gurobi environment.
	# gurobi_1 = JuMP.optimizer_with_attributes(() -> Gurobi.Optimizer(env), "OutputFlag" => 0, "MIPGap" => 0.0);
	# gurobi_2 = JuMP.optimizer_with_attributes(() -> Gurobi.Optimizer(env), "TimeLimit" => 60.0, "NumericFocus" => 3);

	# run_obbt_owf!(network, gurobi_1; model_type = PWLRDWaterModel,
	#     solve_relaxed = false, time_limit = 36.0, max_iter = 100,
	#     ext = Dict(:pipe_breakpoints => 5, :pump_breakpoints => 5));

	# ext = Dict{Symbol, Any}(:pump_breakpoints => 2, :pipe_breakpoints => 2);
	# result = run_mn_owf(network_mn, PWLRDWaterModel, gurobi_2; ext = ext)

	result = JSON.parsefile("../test/data/json/Richmond_skeleton_sol.json"; dicttype=Dict, inttype=Int64, use_mmap=true)

	# ---------------------------------------------------------------------#
	# ------------------------- run unit tests ----------------------------#
	# ---------------------------------------------------------------------#
	solution = result["solution"]
	wntr_network = initialize_wntr_network(data)
	update_wntr_controls(wntr_network, data, solution, float(data["time_step"]))
	wntr_result = simulate_wntr(wntr_network)

	

	## Check if demands are specified correctly
	for (i, demand) in data["nw"]["1"]["demand"]
        # Get nodal information associated with the demand.
        node_id = string(demand["node"])
        node = data["nw"]["1"]["node"][node_id]
        elevation = node["elevation"]

        # test elevation information
        @test check_difference(data["nw"]["1"]["node"][node_id]["elevation"], wntr_network.nodes._data[node_id].elevation, tol) 
        # test demand rate
        for t in network_ids
        	@test check_difference(data["nw"][string(t)]["demand"][i]["flow_nominal"], wntr_result.node["demand"][node_id].values[t], tol)
        end
    end


    ## Check if reservoirs are specified correctly
    for (i, reservoir) in data["nw"]["1"]["reservoir"]
    	node_id = string(reservoir["node"])
        node = data["nw"]["1"]["node"][node_id]
    	for t in network_ids
		    @test check_difference(data["nw"][string(t)]["node"][node_id]["head_nominal"], wntr_result.node["head"][node_id].values[t], tol)
		end
	end

	## Check if tanks are specified correctly 
	for (i, tank) in data["nw"]["1"]["tank"]
        node_id = string(tank["node"])
        node = data["nw"]["1"]["node"][node_id]
        tank_node_name = string(data["nw"]["1"]["tank"][i]["node"])
        @test check_difference(node["elevation"], wntr_network.nodes._data[node_id].elevation, tol)
        @test check_difference(solution["nw"]["1"]["node"][tank_node_name]["p"], wntr_result.node["pressure"][node_id].values[1], tol)
        @test check_difference(tank["min_level"], wntr_network.nodes._data[node_id].min_level, tol)
        @test check_difference(tank["max_level"], wntr_network.nodes._data[node_id].max_level, tol)
        @test check_difference(tank["diameter"], wntr_network.nodes._data[node_id].diameter, tol)
        @test check_difference(tank["min_vol"], wntr_network.nodes._data[node_id].min_vol, tol)
    end

	## Check if bare nodes are specified correctly 
	demand_nodes = [demand["node"] for (i, demand) in data["nw"]["1"]["demand"]]
    tank_nodes = [tank["node"] for (i, tank) in data["nw"]["1"]["tank"]]
    reservoir_nodes = [reservoir["node"] for (i, reservoir) in data["nw"]["1"]["reservoir"]]
    populated_nodes = vcat(demand_nodes, tank_nodes, reservoir_nodes)
    bare_nodes = filter(x -> !(x.second["index"] in populated_nodes), data["nw"]["1"]["node"])
    for (i, node) in bare_nodes
    	node_id = string(node["index"])
    	# elevation
    	@test check_difference(node["elevation"], wntr_network.nodes._data[node_id].elevation, tol)
    	# base demand (should be 0)
    	@test check_difference(wntr_network.nodes._data[node_id].base_demand, 0, tol)
    end



	## Check if pipes are specified correctly 
	for (i, pipe) in data["nw"]["1"]["pipe"]
		if pipe["status"] == 1
			pipe_id = "pipe"*string(pipe["index"])
			node_fr, node_to = string(pipe["node_fr"]), string(pipe["node_to"])
	        length, diameter = pipe["length"], pipe["diameter"]
	        roughness, minor_loss = pipe["roughness"], pipe["minor_loss"]

	        @test node_fr == wntr_network.links._data[pipe_id].start_node_name
	        @test node_to == wntr_network.links._data[pipe_id].end_node_name
	        @test check_difference(length, wntr_network.links._data[pipe_id].length, tol)
	        @test check_difference(diameter, wntr_network.links._data[pipe_id].diameter, tol)
	        @test check_difference(roughness, wntr_network.links._data[pipe_id].roughness, tol)
	        @test check_difference(minor_loss, wntr_network.links._data[pipe_id].minor_loss, tol)
		end
    end


	## Check if pumps are specified correctly
	for (i, pump) in data["nw"]["1"]["pump"]
        if pump["status"] == 1
        	pump_id = "pump"*string(pump["index"])
            node_fr, node_to = string(pump["node_fr"]), string(pump["node_to"])
            @test node_fr == wntr_network.links._data[pump_id].start_node_name
            @test node_to == wntr_network.links._data[pump_id].end_node_name
            @test wntr_network.curves._data["pump_head_curve_"*string(pump["index"])].points == pump["head_curve"]
            if haskey(pump, "efficiency_curve")
                efficiency_curve = pump["efficiency_curve"]
                @test wntr_network.curves._data["pump_eff_curve_"*string(pump["index"])].points == pump["efficiency_curve"]
            else
            	@test wntr_network.options.energy.global_efficiency == pump["efficiency"]
            end

            # check pump controls
            for t in network_ids
            	@test check_difference(solution["nw"][string(t)]["pump"][string(pump["index"])]["status"], wntr_result.link["status"][pump_id].values[t], tol)
            end
        end
    end

    ## Check if short pipes are specified correctly
    for (i, short_pipe) in data["nw"]["1"]["short_pipe"]
    	if short_pipe["status"] == 1
	    	short_pipe_id = "short_pipe"*string(short_pipe["index"])
	        node_fr, node_to = string(short_pipe["node_fr"]), string(short_pipe["node_to"])
	        @test node_fr == wntr_network.links._data[short_pipe_id].start_node_name
            @test node_to == wntr_network.links._data[short_pipe_id].end_node_name
            @test 1.0e-3 == wntr_network.links._data[short_pipe_id].length
            @test 1.0 == wntr_network.links._data[short_pipe_id].diameter
            @test 100.0 == wntr_network.links._data[short_pipe_id].roughness
            @test short_pipe["minor_loss"] == wntr_network.links._data[short_pipe_id].minor_loss
		end
    end

    ## Check if valves are specified correctly
    for (i, valve) in data["nw"]["1"]["valve"]
    	if valve["status"] == 1
    		valve_id = "valve"*string(valve["index"])
    		node_fr, node_to = string(valve["node_fr"]), string(valve["node_to"])
    		@test node_fr == wntr_network.links._data[valve_id].start_node_name
            @test node_to == wntr_network.links._data[valve_id].end_node_name
            @test 1.0e-3 == wntr_network.links._data[valve_id].length
            @test 1.0 == wntr_network.links._data[valve_id].diameter
            @test 100.0 == wntr_network.links._data[valve_id].roughness
            @test valve["minor_loss"] == wntr_network.links._data[valve_id].minor_loss
            @test (string(valve["flow_direction"]) == "POSITIVE") ==  wntr_network.links._data[valve_id].cv
            
            # check valve controls
            for t in network_ids
            	@test check_difference(solution["nw"][string(t)]["valve"][string(valve["index"])]["status"], wntr_result.link["status"][valve_id].values[t], tol)
            end

        end
    end

 
end