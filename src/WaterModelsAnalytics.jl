"""
Module for visualizing water networks, and potentially other graphics
"""
module WaterModelsAnalytics
    # imports
    import WaterModels
    const _WM = WaterModels

    # importing only the viridis color scheme for now; might allow the color scheme to be
    # selected by the user at some point, in which case will need to import all of ColorShemes
    import ColorSchemes.viridis
    import ColorTypes.HSV
    import Statistics.mean
    using Printf

    import Plots

    # Python imports.
    import PyCall
    import PyCall: PyObject, @pycall
    const pgv = PyCall.PyNULL()
    function __init__()
        copy!(pgv, PyCall.pyimport("pygraphviz"))
    end

    include("graph/common.jl")

    export build_graph
    export write_dot
    export run_dot
    export colorbar
    export write_visualization
end
