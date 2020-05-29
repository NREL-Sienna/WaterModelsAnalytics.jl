"""
Module for visualizing water networks, and potentially other graphics
"""
module WaterModelsAnalytics

# imports
import WaterModels
# importing only the viridis color scheme for now; might allow the color scheme to be
# selected by the user at some point, in which case need to import all of ColorShemes
import ColorSchemes.viridis

# python imports
import PyCall
#nx = PyCall.pyimport("networkx") # not precompile safe?
const nx = PyCall.PyNULL()
function __init__()
    copy!(nx, PyCall.pyimport("networkx"))
end

# includes
include("graph/common.jl")

# exports
export build_graph
export write_dot
export run_dot
export write_visualization

end # module
