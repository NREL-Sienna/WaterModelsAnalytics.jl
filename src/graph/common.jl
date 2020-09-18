# TODO:
# - add keyword argument to choose whether to enable/disable showing indices?
# - parse for discrete valves and add labels for those links (valves as part of pipes are
#   done, but that formulation will change at some point anyway!)


"""
Build networkx graph object from a WaterModels network dictionary parsed from an EPANET file.
"""
function build_graph(data::Dict{String,Any},
                     solution::Union{Nothing, Dict{String,Any}}=nothing)
    # presumes input is data dict from WaterModels.parse_file()

    # TODO:
    # - check that input dictionary has the expected fields
    
    G = pgv.AGraph(strict=false, directed=true)

    add_nodes!(G, data["node"])
    node_labels!(G, data["junction"])
    node_labels!(G, data["reservoir"])
    node_labels!(G, data["tank"])
    
    add_links!(G, data["pipe"])
    add_links!(G, data["pump"])
    #add_links!(G, data["valve"]) # doesn't exist now, may become several valve types?

    # if solution dict provided
    if !isnothing(solution)
        add_solution!(G, data, solution)
    end
    
    return G
end # funtion build_graph

"""
Add nodes to the pygraphviz graph object, including node attributes for name label,
elevation, and coordinates
"""
function add_nodes!(G::PyCall.PyObject, nodes::Dict{String,Any})
    # determine max and min elevations and coordinates
    elmin = 1e16 
    elmax = 1e-16
    xmin = 1e16 
    xmax = 1e-16
    ymin = 1e16 
    ymax = 1e-16
    for (key,node) in nodes
        elmin = min(elmin, node["elevation"])
        elmax = max(elmax, node["elevation"])
        if haskey(node, "coordinates")
            coord = node["coordinates"]
            xmin = min(xmin, coord[1])
            xmax = max(xmax, coord[1])
            ymin = min(ymin, coord[2])
            ymax = max(ymax, coord[2])
        end
    end
    xspan = xmax-xmin
    yspan = ymax-ymin
    # scale to use to get "good" position results with graphviz output -- should
    # calculate this systematically from the number of nodes?
    scale = 20
    
    # add elmin and elmax as graph attributes for use in creating a colorbar in
    # colorbar (or via write_visualization)
    PyCall.set!(G."graph_attr", "elmin", elmin)
    PyCall.set!(G."graph_attr", "elmax", elmax)

    # create and populate networkx nodes
    for (key,node) in nodes
        # note that names will be rewritten for junctions, tanks, and reservoirs
        if haskey(node, "source_id")
            name = node["source_id"][2]
        else
            name = node["name"] 
        end

        # add node index to the label if different from the name
        if name==key
            label=name
        else
            label=name*" ("*key*")"
        end
        
        # color by elevation
        elev = node["elevation"]
        clr = HSV(get(viridis, elev, (elmin, elmax)))
        # convert clr to a string that is in a form suitable for graphviz
        clrstr = string(clr.h/360)*" "*string(clr.s)*" "*string(clr.v)
        
        # change font color depending on the background color
        if clr.v < 0.6
            fntclr = "white"
        else
            fntclr = "black"
        end

        if haskey(node, "coordinates")
            coord = node["coordinates"]
            xval = scale*(coord[1] - xmin)/xspan
            yval = scale*(coord[2] - ymin)/yspan
            posstr = string(xval)*","*string(yval)*"!" # exclamation point forces exact
                                                     # positioning when using Neato
            G.add_node(node["index"], label=label, elevation=elev, pos=posstr,
                       style="filled", fillcolor=clrstr, fontcolor=fntclr)
        else
            G.add_node(node["index"], label=label, elevation=elev, style="filled",
                       fillcolor=clrstr, fontcolor=fntclr)
        end
    end
end


""" Add labels for junctions, tanks, and reservoirs."""
function node_labels!(G::PyCall.PyObject, nodes::Dict{String,Any})
    for (key,node) in nodes
        nodekey = node["node"]
        nodeobj = @pycall G."get_node"(nodekey)::PyObject
        name = node["name"]

        # add node index to the label if different from the name
        if name==nodekey
            label = name
        else
            label = name*" ("*string(nodekey)*")"
        end
        
        node_type = node["source_id"][1]
        if node_type == "reservoir"
            PyCall.set!(nodeobj.attr, "label", "Rsvr\n"*label)
        elseif node_type == "tank"
            PyCall.set!(nodeobj.attr, "label", "Tank\n"*label)
        else
            dem = node["demand"]
            if dem==0
                PyCall.set!(nodeobj.attr, "label", label)
            else
                dem = @sprintf("%2.2g", dem)
                PyCall.set!(nodeobj.attr, "label", label*"\nd: "*dem)
            end
        end
    end
end

"""
Add links to the graph with a label denoting type, name, and length
"""
function add_links!(G::PyCall.PyObject, links::Dict{String,Any})
    for (key,link) in links
        link_type = link["source_id"][1]
        name = link["name"]
        # add link index to the label if different from the name
        if name==key
            label = name
        else
            label = name*" ("*key*")"
        end
        
        if link_type == "pump"
            G.add_edge(link["node_fr"], link["node_to"], link["index"],
                       label="Pmp\n"*label, color="red", style="bold")
#  distinct valves TBD
#        elseif link_type == "valve" 
#            println("valves not yet implemented")
        else # it is a pipe
            length = @sprintf("%2.2g m", link["length"])
            if link["has_shutoff_valve"]
                G.add_edge(link["node_fr"], link["node_to"], key,
                           label="SV\n"*label*"\n"*length)
            elseif link["has_check_valve"]
                G.add_edge(link["node_fr"], link["node_to"], key,
                           label="CV\n"*label*"\n"*length)
            else
                G.add_edge(link["node_fr"], link["node_to"], key,
                           label=label*"\n"*length)
            end
        end
    end
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
    # add flow to the labels for pipes and check- and shutoff-valves
    pipesplus = [solution["pipe"], solution["check_valve"], solution["shutoff_valve"]]
    for dict in pipesplus
        for (key,pipesol) in dict
            flow = @sprintf("%2.2g", pipesol["q"])
            pipe = data["pipe"][key]
            # may also need to use `key` if multiple pipes between nodes 
            edgeobj = @pycall G."get_edge"(pipe["node_fr"], pipe["node_to"])::PyObject 
            label = get(edgeobj.attr, "label")
            PyCall.set!(edgeobj.attr, "label", label*"\nq: "*flow)
        end
    end
    # add flow and gain to the pump labels 
    for (key,pumpsol) in solution["pump"]
        flow = @sprintf("%2.2g", pumpsol["q"])
        gain = @sprintf("%2.2g", pumpsol["g"])
        pump = data["pump"][key]
        # may also need to use `key` if multiple pumps between nodes 
        edgeobj = @pycall G."get_edge"(pump["node_fr"], pump["node_to"])::PyObject 
        label = get(edgeobj.attr, "label")
        PyCall.set!(edgeobj.attr, "label", label*"\nq: "*flow*"\ng: "*gain)
    end
end


""" 
Write out to a file a visualization for a WaterModels network dictionary parsed from an
EPANET file. `basefilename` should not include an extension and will be appended with
`_w_cb.pdf` in the final output file, which is a multi-page PDF. The `layout` option equates
to the layout functions of graphviz (dot, neato, etc.). Use `del_files=false` to keep the
intermediate files.
"""
function write_visualization(data::Dict{String,Any}, basefilename::String,
                             solution::Union{Nothing, Dict{String,Any}}=nothing;
                             layout::String="dot", del_files::Bool=true)
    # TODO:
    # - pass through arguments to `write_graph`

    #gvfile = basefilename*".gv"
    pdffile = basefilename*".pdf"
    cbfile = basefilename*"_cbar.pdf"
    outfile = basefilename*"_w_cb.pdf"
    
    G = build_graph(data, solution)
    write_graph(G, pdffile, layout)
    colorbar(G, cbfile)

    # add option -dAutoRotatePages=/None ?
    run(`gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$outfile $cbfile $pdffile`)
    # delete the intermediate files
    if del_files
        run(`rm $pdffile $cbfile`)
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
        @warn "$layout is not a supported layout; dot used instead"
        G.draw(filename, prog="dot")
    end
end


"""
create and save a colorbar that represents the node elevations
"""
function colorbar(G::PyCall.PyObject, filename::String)
    elmin = parse(Float64, get(G.graph_attr, "elmin"))
    elmax = parse(Float64, get(G.graph_attr, "elmax"))
    elmid = elmin + (elmax-elmin)/2
    
    x = reshape(collect(range(0.0, stop=1.0, length=100)), (1,:))
    Plots.heatmap(x, c=:viridis, size=(500,100), legend=:none, yaxis=false)
    Plots.plot!(xticks=(0:50:100, [elmin, elmid, elmax]))
    Plots.title!("Elevation")
    Plots.savefig(filename)
end
