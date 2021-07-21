
# TODO:
# * add plotting head/pressure of nodes
# * better and more complete docstrings
# * allow user to provide color and/or symbol for plotting the series data
# * add tests

# Is there a need to plot only WNTR results? I can't think of any at the moment, JJS 7/13/21


"""
Plot tank levels for the specified tank as calculated from WaterModels.
"""
function plot_tank(tank_id::String, wm_data::Dict{String,<:Any},
                   wm_solution::Dict{String,<:Any}; kwargs...)
    tank = wm_data["nw"]["1"]["tank"][tank_id]
    tank_node_id = string(tank["node"])
    tank_name = string(tank["name"])
    tank_df = get_tank_dataframe(tank_id, wm_data, wm_solution)

    p = Plots.plot(xlabel="time [h]", ylabel="level [m]"; kwargs...)
    Plots.plot!(p, tank_df.time, tank_df.level_watermodels, lw=2,
                label="tank $tank_name (node $tank_node_id)")
    clr = p.series_list[end].plotattributes[:linecolor]
    Plots.plot!(p, tank_df.time, tank["min_level"]*ones(length(tank_df.time)),
                linecolor=clr, linestyle=:dot, label="")
    Plots.plot!(p, tank_df.time, tank["max_level"]*ones(length(tank_df.time)),
                linecolor=clr, linestyle=:dot, label="")

    return p
end 


"""
Add tank levels for the specified tank to a plot
"""
function plot_tank!(p::Plots.Plot, tank_id::String, wm_data::Dict{String,<:Any},
                    wm_solution::Dict{String,<:Any})
    tank = wm_data["nw"]["1"]["tank"][tank_id]
    tank_node_id = string(tank["node"])
    tank_name = string(tank["name"])    
    tank_df = get_tank_dataframe(tank_id, wm_data, wm_solution)
    
    Plots.plot!(p, tank_df.time, tank_df.level_watermodels, lw=2,
                label="tank $tank_name (node $tank_node_id)")
    clr = p.series_list[end].plotattributes[:linecolor]
    Plots.plot!(p, tank_df.time, tank["min_level"]*ones(length(tank_df.time)),
                linecolor=clr, linestyle=:dot, label="")
    Plots.plot!(p, tank_df.time, tank["max_level"]*ones(length(tank_df.time)),
                linecolor=clr, linestyle=:dot, label="")

    return p
end

plot_tank!(tank_id::String, wm_data::Dict{String,<:Any}, wm_solution::Dict{String,<:Any}) =
    plot_tank!(Plots.current(), tank_id, wm_data, wm_solution)


""" 
Plot tank levels for all tanks as calculated from WaterModels. Currently plots all results
in the same figure.
"""
function plot_tanks(wm_data::Dict{String,<:Any}, wm_solution::Dict{String,<:Any}; kwargs...)
    tank_ids = collect(keys(wm_data["nw"]["1"]["tank"]))

    p = plot_tank(tank_ids[1], wm_data, wm_solution; kwargs...)
    
    for i in range(2, stop=length(tank_ids))
        plot_tank!(p, tank_ids[i], wm_data, wm_solution)
    end
    return p
end


"""
Plot tank levels for the specified tank as calculated from WaterModels and WNTR.
"""
function plot_tank(tank_id::String, wm_data::Dict{String,<:Any},
                   wm_solution::Dict{String,<:Any}, wntr_data::PyCall.PyObject,
                   wntr_result::PyCall.PyObject; kwargs...)
    tank = wm_data["nw"]["1"]["tank"][tank_id]
    tank_node_id = string(tank["node"])
    tank_name = string(tank["name"])
    tank_df = get_tank_dataframe(tank_id, wm_data, wm_solution, wntr_data, wntr_result)

    p = Plots.plot(xlabel="time [h]", ylabel="level [m]",
                   title="tank $tank_name (node $tank_node_id)"; kwargs...)
    Plots.plot!(p, tank_df.time, tank_df.level_watermodels, lw=2, label="WaterModel")
    Plots.plot!(p, tank_df.time, tank_df.level_wntr, lw=2, label="WNTR")
    Plots.plot!(p, tank_df.time, tank["min_level"]*ones(length(tank_df.time)),
                linecolor=:black, linestyle=:dot, label="")
    Plots.plot!(p, tank_df.time, tank["max_level"]*ones(length(tank_df.time)),
                linecolor=:black, linestyle=:dot, label="")

    return p
end 


"""
Plot tank levels for all tanks as calculated from WaterModels and WNTR. Currently creates a
separate plot for each tank.
"""
function plot_tanks(wm_data::Dict{String,<:Any}, wm_solution::Dict{String,<:Any},
                    wntr_data::PyCall.PyObject, wntr_result::PyCall.PyObject;
                    screen::Bool=true, basepath::Union{Nothing, String}=nothing,
                    extension::String="pdf")
    tank_ids = keys(wm_data["nw"]["1"]["tank"])
    for tank_id in tank_ids
        p = plot_tank(tank_id, wm_data, wm_solution, wntr_data, wntr_result; reuse=false)
        if screen
            display(p)
        end
        if !isnothing(basepath)
            tank_name = string(wm_data["nw"]["1"]["tank"][tank_id]["name"])
            savepath = basepath*"_"*tank_name*"."*extension
            Plots.savefig(p, savepath)
        end
    end
end
