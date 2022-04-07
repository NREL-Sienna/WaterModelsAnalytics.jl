"""
Module for visualizing water networks, and potentially other graphics
"""
module WaterModelsAnalytics
# imports
import WaterModels
const _WM = WaterModels
const _IM = WaterModels._IM

# importing only the viridis color scheme for now; might allow the color scheme to be
# selected by the user at some point, in which case will need to import all of ColorSchemes
import ColorSchemes.viridis
import ColorTypes.HSV
import Memento
import Statistics.mean
using Printf

import Interpolations
const _ITP = Interpolations

import Plots
import DataFrames
using LaTeXStrings

# Python imports.
import PyCall
import PyCall: PyObject, @pycall
const pgv = PyCall.PyNULL()
const wntr = PyCall.PyNULL()
const wntrctrls = PyCall.PyNULL()
const wntr_vis = PyCall.PyNULL()
const stack_cbar = PyCall.PyNULL()
const collate_viz = PyCall.PyNULL()

# Create our module-level logger (this will get precompiled).
const _LOGGER = Memento.getlogger(@__MODULE__)


function __init__()
    # alert about warnings generated during the build of the package (warnings are not shown
    # in the REPL)
    _build_log = joinpath(dirname(dirname(@__FILE__)), "deps", "build.log")

    if isfile(_build_log) && occursin("Warning:", read(_build_log, String))
        @warn("Warnings were generated during the last build of WaterModelsAnalytics.jl:  please check the build log at $_build_log")
    end    
    
    # Register the module-level logger at runtime so users can access the logger via
    # `getlogger(WaterModelsAnalytics)` NOTE: If this line is not included, then the
    # precompiled `WaterModelsAnalytics._LOGGER` will not be registered at runtime.
    Memento.register(_LOGGER)

    try
        # Import WNTR-related components.
        PyCall.pyimport("wntr")
        copy!(wntr, PyCall.pyimport("wntr"))
        copy!(wntrctrls, PyCall.pyimport("wntr.network.controls"))
        wntr_vis_path = joinpath(dirname(pathof(@__MODULE__)), "python")

        PyCall.py"""
        import sys; sys.path.insert(0, $(wntr_vis_path))
        """

        copy!(wntr_vis, PyCall.pyimport("wntr_vis"))
        copy!(stack_cbar, wntr_vis.stack_cbar)
        copy!(collate_viz, wntr_vis.collate_viz)
    catch
        error("Python installation is missing the \"wntr\" module.")
    end

    try
        # Import pygraphviz-related components.
        PyCall.pyimport("pygraphviz")
        copy!(pgv, PyCall.pyimport("pygraphviz"))
    catch
        error("Python installation is missing the \"pygraphviz\" module.")
    end
end


"Suppresses information and warning messages output by WaterModelsAnalytics. For more
        fine-grained control, use the Memento package."
function silence()
    Memento.info(_LOGGER, "Suppressing information and warning messages for "
                 * "the rest of this session. Use the Memento package for more "
                 * "fine-grained control of logging.")
    Memento.setlevel!(Memento.getlogger(_IM), "error")
    Memento.setlevel!(Memento.getlogger(_WM), "error")
end


"Allows the user to set the logging level without the need to add Memento."
function logger_config!(level)
    Memento.config!(Memento.getlogger("WaterModelsAnalytics"), level)
end


include("analysis/utility.jl")
include("analysis/simulation.jl")
include("analysis/validation.jl")
include("analysis/pump_bep.jl")

include("graph/graph.jl")
include("graph/output.jl")

include("plots/pumps.jl")
include("plots/nodes.jl")
include("plots/links.jl")

export build_graph
export update_graph
export write_graph
export write_visualization
export write_multi_time_viz

export initialize_wntr_network
export update_wntr_controls
export simulate_wntr

export get_node_dataframe
export get_tank_dataframe
export get_pipe_dataframe
export get_short_pipe_dataframe
export get_valve_dataframe
export get_pump_dataframe
export compute_pump_power

export compare_tank_level

export calc_pump_bep!
export plot_pumps
export plot_tank
export plot_tanks

end # module WaterModelsAnalytics
