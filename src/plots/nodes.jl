
# TODO:
# * when get_dataframe methods can return just WM info, then allow plotting only WM results
# * add plotting head/pressure of nodes

"""
Plot tank levels for the specified tank as calculated from WaterModels and WNTR.
"""
function plot_tank(tank_id::String, wm_data::Dict{String,<:Any},
                   wm_solution::Dict{String,<:Any}, wntr_data::PyCall.PyObject,
                   wntr_result::PyCall.PyObject; screen::Bool=true, reuse::Bool=true,
                   savepath::Union{Nothing, String}=nothing)
    tank = wm_data["nw"]["1"]["tank"][tank_id]
    tank_node_id = string(tank["node"])
    tank_name = string(tank["name"])
    tank_df = get_tank_dataframe(wm_data, wm_solution, wntr_data, wntr_result, tank_id)

    p = Plots.plot(xlabel="time [h]", ylabel="level [m]",
                   title="tank $tank_name (node $tank_node_id)", legend=:top, reuse=reuse)
    Plots.plot!(p, tank_df.time, tank_df.level_watermodels, lw=2, label="WaterModel")
    Plots.plot!(p, tank_df.time, tank_df.level_wntr, lw=2, label="WNTR")
    Plots.plot!(p, tank_df.time, tank["min_level"]*ones(length(tank_df.time)),
                linecolor=:black, linestyle=:dot, label="")
    Plots.plot!(p, tank_df.time, tank["max_level"]*ones(length(tank_df.time)),
                linecolor=:black, linestyle=:dot, label="")

    if screen
        display(p)
    end
    if !isnothing(savepath)
        Plots.savefig(p, savepath)
    end
end 

"""
Plot tank levels for all tanks as calculated from WaterModels and WNTR.
"""
function plot_tanks(wm_data::Dict{String,<:Any}, wm_solution::Dict{String,<:Any},
                    wntr_data::PyCall.PyObject, wntr_result::PyCall.PyObject;
                    screen::Bool=true, basepath::Union{Nothing, String}=nothing,
                    extension::String="pdf")
    tank_ids = keys(wm_data["nw"]["1"]["tank"])
    for tank_id in tank_ids
        if isnothing(basepath)
            savepath = nothing
        else
            tank_name = string(wm_data["nw"]["1"]["tank"][tank_id]["name"])
            savepath = basepath*"_"*tank_name*"."*extension
        end
        plot_tank(tank_id, wm_data, wm_solution, wntr_data, wntr_result,
                  screen=screen, reuse=false, savepath=savepath)
    end
end
