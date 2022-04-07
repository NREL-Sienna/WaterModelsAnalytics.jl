# TODO:
# * add plotting of pumps, analagous to pipes but head gain rather than loss as an option
# * better and more complete docstrings
# * allow user to provide color and/or symbol for plotting the series data
# * add tests
# * check for and use correct units in plot labels

# Is there a need to plot only WNTR results? I can't think of any at the moment, JJS 7/13/21


"""
Plot pipe flow or head-loss for the specified pipe as calculated from WaterModels.
"""
function plot_pipe(pipe_id::String, wm_data::Dict{String,<:Any},
                   wm_solution::Dict{String,<:Any}; vrbl=:flow_watermodels, kwargs...)
    pipe = wm_data["nw"]["1"]["pipe"][pipe_id]
    pipe_name = string(pipe["name"])
    pipe_df = get_pipe_dataframe(pipe_id, wm_data, wm_solution)
    if vrbl == :flow_watermodels
        ylabel = "flow"
    elseif vrbl == :hl_watermodels
        ylabel = "head loss"
    else
        error("$vrbl is not a valid variable to plot for pipes")
    end
    
    p = Plots.plot(xlabel="time [h]", ylabel=ylabel; kwargs...)
    clr = 1 # this will be the first line
    Plots.plot!(p, pipe_df.time, pipe_df[!,vrbl], lw=2,
                color=clr, label="pipe $pipe_name ($pipe_id)")
    if vrbl == :flow_watermodels
        Plots.plot!(p, pipe_df.time, pipe["flow_min"]*ones(length(pipe_df.time)),
                    color=clr, linestyle=:dot, label="")
        Plots.plot!(p, pipe_df.time, pipe["flow_max"]*ones(length(pipe_df.time)),
                    color=clr, linestyle=:dot, label="")
    end
    return p
end 

"""
Add pipe flow or head-loss for the specified pipe to a plot
"""
function plot_pipe!(p::Plots.Plot, pipe_id::String, wm_data::Dict{String,<:Any},
                   wm_solution::Dict{String,<:Any}; vrbl=:flow_watermodels, kwargs...)
    pipe = wm_data["nw"]["1"]["pipe"][pipe_id]
    pipe_name = string(pipe["name"])
    pipe_df = get_pipe_dataframe(pipe_id, wm_data, wm_solution)
    if vrbl == :flow_watermodels
        ylabel = "flow"
    elseif vrbl == :hl_watermodels
        ylabel = "head loss"
    else
        error("$vrbl is not a valid variable to plot for pipes")
    end

    if vrbl == :flow_watermodels
        clr = Int(length(p.series_list)/3 + 1) # 3 lines per color -- increment just one
    else
        clr = Int(length(p.series_list) + 1)
    end
    Plots.plot!(p, pipe_df.time, pipe_df[!,vrbl], lw=2,
                color=clr, label="pipe $pipe_name ($pipe_id)")
    if vrbl == :flow_watermodels
        Plots.plot!(p, pipe_df.time, pipe["flow_min"]*ones(length(pipe_df.time)),
                    color=clr, linestyle=:dot, label="")
        Plots.plot!(p, pipe_df.time, pipe["flow_max"]*ones(length(pipe_df.time)),
                    color=clr, linestyle=:dot, label="")
    end
    return p
end 

plot_pipe!(pipe_id::String, wm_data::Dict{String,<:Any}, wm_solution::Dict{String,<:Any};
           kwargs...) = plot_pipe!(Plots.current(), pipe_id, wm_data, wm_solution; kwargs...)
