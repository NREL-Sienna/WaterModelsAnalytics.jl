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

# Create our module-level logger (this will get precompiled).
const _LOGGER = Memento.getlogger(@__MODULE__)

function __init__()
    copy!(pgv, PyCall.pyimport("pygraphviz"))
    copy!(wntr, PyCall.pyimport("wntr"))
    copy!(wntrctrls, PyCall.pyimport("wntr.network.controls"))
    copy!(wntr_vis, PyCall.pyimport("wntr_vis")) # this works! somehow it's in the path
    copy!(stack_cbar, wntr_vis.stack_cbar)
    
    # Register the module-level logger at runtime so users can access the logger via
    # `getlogger(WaterModelsAnalytics)` NOTE: If this line is not included, then the
    # precompiled `WaterModelsAnalytics._LOGGER` will not be registered at runtime.
    Memento.register(_LOGGER)
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
include("analysis/visualization.jl")
include("analysis/pump_bep.jl")
include("graph/common.jl")
include("plots/pumps.jl")

export build_graph
export write_graph
export colorbar
export write_visualization

export simulate
export get_node_dataframe
export get_tank_dataframe
export get_pipe_dataframe
export get_short_pipe_dataframe
export get_valve_dataframe
export get_pump_dataframe

# export compare_tank_head
export compare_tank_level

export calc_pump_bep!
export plot_pumps

end # module WaterModelsAnalytics
