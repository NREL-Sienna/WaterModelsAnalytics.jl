# TODO:
# - use keyword argument to enable/disable showing indices?
# - parse the "status" flag for every node and edge? needed for `des_pipes` (design
#   problem); not sure of other use cases
# * for "epanet-data" objects, identify shutoff valves; might want to do that in
#   WaterModels?



"""
Build pygraphviz graph object from a WaterModels network dictionary parsed from an EPANET
file. If a `solution` dict is provided, it should be for the same time as that of the `data`
dict.
"""
function build_graph(data::Dict{String, <:Any},
                     solution::Union{Nothing, Dict{String, <:Any}} = nothing)
    # presumes input is data dict from WaterModels.parse_file() OR WaterModels.parse_epanet()

    # TODO:
    # - check that input dictionary has the expected fields
    
    G = pgv.AGraph(strict = false, directed = true)

    # Add nodal data to the directed graph object.
    add_nodes!(G, data["node"])
    node_labels!(G, data["demand"]) 
    node_labels!(G, data["reservoir"])
    node_labels!(G, data["tank"])

    # Add link data to the directed graph object.
    max_pipe_diameter = maximum([x.second["diameter"] for x in data["pipe"]])
    _add_pipe_to_graph!.(Ref(G), values(data["pipe"]), max_pipe_diameter)
    _add_des_pipe_to_graph!.(Ref(G), values(data["des_pipe"]))
    _add_short_pipe_to_graph!.(Ref(G), values(data["short_pipe"]))
    _add_pump_to_graph!.(Ref(G), values(data["pump"]))
    _add_regulator_to_graph!.(Ref(G), values(data["regulator"]))
    _add_valve_to_graph!.(Ref(G), values(data["valve"]))

    # if solution dict provided
    if solution !== nothing
        add_solution!(G, data, solution)
    end
    
    return G
end # function build_graph

"""
Add nodes to the pygraphviz graph object, including node attributes for name label,
elevation, and coordinates
"""
function add_nodes!(G::PyCall.PyObject, nodes::Dict{String,Any})
    # Determine minimum and maximum elevations.
    elevation_min = minimum([x["elevation"] for x in values(nodes)])
    elevation_max = maximum([x["elevation"] for x in values(nodes)])

    # Determine minimum and maximum coordinate values.
    if all(map(x -> haskey(x, "coordinates"), values(nodes)))
        x_min = minimum([x["coordinates"][1] for x in values(nodes)])
        x_max = maximum([x["coordinates"][1] for x in values(nodes)])
        y_min = minimum([x["coordinates"][2] for x in values(nodes)])
        y_max = maximum([x["coordinates"][2] for x in values(nodes)])
    else
        x_min, x_max, y_min, y_max = Inf, -Inf, Inf, -Inf
    end

    # scale to use to achieve "good" relative positioning with graphviz output --
    # calculate this systematically from the number of nodes?
    scale = 20.0
    
    # add elmin and elmax as graph attributes for use in creating a colorbar in
    # colorbar (or via write_visualization)
    PyCall.set!(G."graph_attr", "elmin", elevation_min)
    PyCall.set!(G."graph_attr", "elmax", elevation_max)

    # create and populate pygraphviz nodes
    for (key, node) in nodes
        # Get the label to be used for the node.
        label = _get_comp_label(node)
        
        # Color according to the node's elevation.
        clr = HSV(get(viridis, node["elevation"], (elevation_min, elevation_max)))

        # Convert clr to a string that is in a form suitable for graphviz.
        clrstr = string(clr.h / 360) * " " * string(clr.s) * " " * string(clr.v)

        # Change font color depending on the background color.
        fntclr = clr.v < 0.6 ? "white" : "black"

        if all(map(x -> haskey(x, "coordinates"), values(nodes)))
            # Get scaled version of the coordinates.
            x = scale * (node["coordinates"][1] - x_min) / (x_max - x_min)
            y = scale * (node["coordinates"][2] - y_min) / (y_max - y_min)

            # Exclamation point forces exact positioning using Neato.
            pos = string(x) * "," * string(y) * "!"

            # Add the node to the graph object with specified attributes.
            G.add_node(node["index"], label = label, elevation = node["elevation"],
                pos = pos, style = "filled", fillcolor = clrstr, fontcolor = fntclr)
        else
            # Add the node to the graph object with specified attributes.
            G.add_node(node["index"], label = label, elevation = node["elevation"],
                style = "filled", fillcolor = clrstr, fontcolor = fntclr)
        end
    end
end


"""Add labels for junctions, tanks, and reservoirs."""
function node_labels!(G::PyCall.PyObject, nodes::Dict{String,Any})
    for (key, node) in nodes
        nodekey = node["node"]
        nodeobj = @pycall G."get_node"(nodekey)::PyObject
        name = node["name"]

        # add node index to the label if different from the name
        if name==string(nodekey)
            label = name
        else
            label = name*" ("*string(nodekey)*")"
        end

        # will the node type ever change from the original source_id description? some link
        # types do (pipes -> valves)
        node_type = node["source_id"][1]
        
        if node_type == "reservoir"
            PyCall.set!(nodeobj.attr, "label", "Rsvr\n"*label)
            PyCall.set!(nodeobj.attr, "shape", "diamond")
        elseif node_type == "tank"
            PyCall.set!(nodeobj.attr, "label", "Tank\n"*label)
            PyCall.set!(nodeobj.attr, "shape", "rectangle")
        else
            dem = node["flow_nominal"] 

            if dem == 0
                PyCall.set!(nodeobj.attr, "label", label)
            else
                dem = @sprintf("%2.2g", dem)
                PyCall.set!(nodeobj.attr, "label", label*"\nd: "*dem)
            end
        end
    end
end


function _get_comp_label(comp::Dict{String, <:Any})
    source_name = comp["source_id"][2]

    if string(comp["index"]) == source_name
        return source_name
    else
        return "$(source_name) ($(string(comp["index"])))"
    end
end


function _get_link_arrowhead(link::Dict{String, <:Any})
    return "normal"
end


function _get_link_dir(link::Dict{String, <:Any})
    if link["flow_direction"] == _WM.UNKNOWN
        return "none"
    elseif link["flow_direction"] == _WM.POSITIVE
        return "forward"
    elseif link["flow_direction"] == _WM.NEGATIVE
        return "back"
    end
end


function _add_pipe_to_graph!(graph::PyCall.PyObject, pipe::Dict{String, <:Any}, max_diameter::Float64)
    index, label = string(pipe["index"]), _get_comp_label(pipe)
    penwidth = pipe["diameter"] * inv(max_diameter) * 10.0
    if penwidth > 8.0
        pad = "  "
    elseif penwidth > 4.0
        pad = " "
    else
        pad = ""
    end
    dir, arrowhead = _get_link_dir(pipe), _get_link_arrowhead(pipe)
    length = @sprintf("%.5g m", pipe["length"])
    graph.add_edge(pipe["node_fr"], pipe["node_to"], index, dir = dir, headclip = "true",
                   arrowhead = arrowhead, penwidth = penwidth,
                   label = "$(pad)$(label)\n$(pad)$(length)")
end


function _add_des_pipe_to_graph!(graph::PyCall.PyObject, des_pipe::Dict{String, <:Any})
    _add_pipe_to_graph!(graph, des_pipe, 1.0)
end


function _add_short_pipe_to_graph!(graph::PyCall.PyObject, short_pipe::Dict{String, <:Any})
    index, label = string(short_pipe["index"]), _get_comp_label(short_pipe)
    dir, arrowhead = _get_link_dir(short_pipe), _get_link_arrowhead(short_pipe)
    graph.add_edge(short_pipe["node_fr"], short_pipe["node_to"], index,
        dir = dir, arrowhead = arrowhead, label = "$(label)")
end


function _add_pump_to_graph!(graph::PyCall.PyObject, pump::Dict{String, <:Any})
    index, label = string(pump["index"]), _get_comp_label(pump)
    dir, arrowhead = _get_link_dir(pump), _get_link_arrowhead(pump)
    graph.add_edge(pump["node_fr"], pump["node_to"], index, dir = dir,
        arrowhead = arrowhead, label = "Pmp\n$(label)", color = "red", style = "bold")
end


function _add_regulator_to_graph!(graph::PyCall.PyObject, regulator::Dict{String, <:Any})
    index, label = string(regulator["index"]), _get_comp_label(regulator)
    dir, arrowhead = _get_link_dir(regulator), _get_link_arrowhead(regulator)
    graph.add_edge(regulator["node_fr"], regulator["node_to"], index, dir = dir,
        arrowhead = arrowhead, label = "Reg\n$(label)", color = "purple", style = "bold")
end


function _add_valve_to_graph!(graph::PyCall.PyObject, valve::Dict{String, <:Any})
    index, label = string(valve["index"]), _get_comp_label(valve)
    dir, arrowhead = _get_link_dir(valve), _get_link_arrowhead(valve)
    if dir != "none"
        label = "CV\n$(label)"
    else
        label = "SV\n$(label)"
    end
    graph.add_edge(valve["node_fr"], valve["node_to"], index, dir = dir,
        arrowhead = arrowhead, label = label, color = "blue", style = "bold")
end


"""
add solution values to the node and link labels
"""
function add_solution!(G::PyCall.PyObject, data::Dict{String,Any},
                       solution::Dict{String,Any})
    # add head to the node labels (could alternatively show pressure)
    for (key,node) in solution["node"]
        head = @sprintf("%2.2g", node["h"])
        nodeobj = @pycall G."get_node"(key)::PyObject
        label = get(nodeobj.attr, "label")
        PyCall.set!(nodeobj.attr, "label", label*"\nh: "*head)
    end
    # add flow to the labels for pipes and valves
    # Byron added this set, but not all of these fields exist in the solution object
    #pipesplus = ["pipe", "des_pipe", "pump", "regulator", "short_pipe", "valve"]
    links = ["pump", "pipe", "valve"]
    for linktype in links
        for (key,pipesol) in solution[linktype]
            flow = _val_string_cut(pipesol["q"], 1e-10)
            link = data[linktype][key]
            # may also need to use `key` if multiple pipes between nodes 
            edgeobj = @pycall G."get_edge"(link["node_fr"], link["node_to"])::PyObject 
            label = get(edgeobj.attr, "label")
            PyCall.set!(edgeobj.attr, "label", label*"\nq: "*flow)
        end
    end
end


function _val_string_cut(val::Real, cut::Real)
    if val < cut
        return "0"
    else
        return @sprintf("%2.2g", val)
    end
end


""" 
Write out to a file a visualization for a WaterModels network dictionary parsed from an
EPANET file. `basefilename` should not include an extension and will be appended with
`_w_cb.pdf` in the final output file, which is a multi-page PDF. The `layout` option equates
to the layout functions of graphviz (dot, neato, etc.). Use `del_files=false` to keep the
intermediate files. If a `solution` dict is provided, it should be for the same time as that
of the `data` dict.
"""
function write_visualization(data::Dict{String,Any}, basefilename::String,
                             solution::Union{Nothing, Dict{String,Any}}=nothing;
                             layout::String="dot", sep_page::Bool=false,
                             del_files::Bool=true)
    # TODO:
    # - pass through general graphviz arguments to `write_graph`

    #gvfile = basefilename*".gv"
    gpdffile = basefilename*"_graph.pdf"
    cbfile = basefilename*"_cbar.pdf"
    outfile = basefilename*"_graph_w_cb.pdf"
    
    G = build_graph(data, solution)
    write_graph(G, gpdffile, layout)
    colorbar(G, cbfile)

    # note that `stack_bar` is a python function from `wntr_vis.py`
    stack_cbar(gpdffile, cbfile, outfile, sep_page)
    
    # delete the intermediate files
    if del_files
        run(`rm $gpdffile $cbfile`)
    end
end


"""
Use graphviz (via pygraphviz) to output a visualization to a file for a graph. The
`layout` option equates to the layout functions of graphviz (dot, neato, etc.).
"""
function write_graph(G::PyCall.PyObject, filename::String, layout::String="dot")
    # TODO:
    # - allow other arguments to be passed through to graphviz
    try
        G.draw(filename, prog=layout)
    catch
        G.draw(filename, prog="dot")
        # by putting this warning after, it should display only if `G.draw()` was actually
        # successful using "dot"; if it fails for another reason, that error should be shown
        @warn "$layout is not a supported layout; dot was used instead"
    end
end


"""
create and save a colorbar that represents the node elevations
"""
function colorbar(G::PyCall.PyObject, filename::String)
    elmin = parse(Float64, get(G.graph_attr, "elmin", 0.0))
    elmax = parse(Float64, get(G.graph_attr, "elmax", 1.0))
    elmid = elmin + 0.5 * (elmax - elmin)
    
    x = reshape(collect(range(0.0, stop=1.0, length=100)), (1,:))
    Plots.heatmap(x, c=:viridis, size=(500,100), legend=:none, yaxis=false)
    Plots.plot!(xticks=(0:50:100, [elmin, elmid, elmax]))
    Plots.plot!(yticks=false) # a regression requires this for GR, JJS 1/4/21,
                              # https://github.com/JuliaPlots/Plots.jl/issues/3019
    Plots.title!("Elevation")
    println(filename)
    Plots.savefig(filename)
end
