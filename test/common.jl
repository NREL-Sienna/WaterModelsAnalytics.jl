## input the tolerance for mismatch
tol = 1e-2
function check_difference(a,b,tol)
	return abs((a-b)/(a+b+1e-7)) <= tol
end

## Parse the network data
wm_path = joinpath(dirname(pathof(_WM)), "..")
network = _WM.parse_file("$(wm_path)/examples/data/epanet/van_zyl.inp")
network_mn = _WM.make_multinetwork(network)

network_ids = sort([parse(Int, nw) for (nw, nw_data) in network_mn["nw"]])

# parse a feasible solution
result = JSON.parsefile("data/json/van_zyl_PWLRD_feasible_sol.json"; dicttype=Dict,
                        inttype=Int64, use_mmap=true)

solution = result["solution"]
wntr_network = initialize_wntr_network(network_mn)
update_wntr_controls(wntr_network, network_mn, solution, float(network_mn["time_step"]))
wntr_result = simulate_wntr(wntr_network)
