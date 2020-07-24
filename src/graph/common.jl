# TODO:
# - parse for discrete valves and add labels for those links (valves as part of pipes are
#   done)
# x parse for demand at nodes and add demand labels
# x add fill color for each node that scales with elevation
# x add colorbar for elevation colors (how to do it?)
# x add an indication of edge length
# x add coordinates for the nodes
# - allow user to choose an output style that uses coordinates


"""
Build networkx graph object from a WaterModels network dictionary parsed from an EPANET file.
"""
function build_graph(data::Dict{String,Any})
    # presumes input is data dict from WaterModels.parse_file()

    # TODO:
    # - check that input dictionary has the expected fields
    
    G = pgv.AGraph(strict=false, directed=true)

    add_nodes!(G, data["node"])
    demand!(G, data["junction"])
    
    add_links!(G, data["pipe"])
    add_links!(G, data["pump"])
    add_links!(G, data["valve"])
    
    return G
end # funtion build_graph


function add_nodes!(G::PyCall.PyObject, nodes::Dict{String,Any})
    # This needs to be redone. Nodes are now disctinct from junctions, tanks, and reservoirs. JJS 7/22/20

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
        node_type = node["source_id"][1]
        if node_type == "reservoir"
            name = "Rsvr\n"*node["name"]
        elseif node_type == "tank"
            name = "Tank\n"*node["name"]
        else
            name = node["name"]
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
            G.add_node(node["index"], label=name, elevation=elev, pos=posstr,
                       style="filled", fillcolor=clrstr, fontcolor=fntclr)
        else
            G.add_node(node["index"], label=name, elevation=elev, style="filled",
                       fillcolor=clrstr, fontcolor=fntclr)
        end
    end
end


""" Add demand label for junctions."""
function demand!(G::PyCall.PyObject, junctions::Dict{String,Any})
    for (key,junction) in junctions
        #### are the keys in data["node"] alwyas equal to string(index) ??? will
        #### presume so for now, JJS 7/7/20
        ## I don't think this bit is needed with pygraphviz, JJS 7/17/20
        # if typeof(key) == String
        #     index = parse(Int, key)
        # else
        #     index = key
        # end

        nodeobj = @pycall G."get_node"(key)::PyObject
        name = get(nodeobj.attr, "label")
        dem = @sprintf("%2.2g", junction["demand"])
        PyCall.set!(nodeobj.attr, "label", name*"\nd = "*dem)
    end
end


function add_links!(G::PyCall.PyObject, links::Dict{String,Any})
    for (key,link) in links
        link_type = link["source_id"][1]
        if link_type == "pump"
            G.add_edge(link["node_fr"], link["node_to"], link["index"],
                       label="P "*link["name"], color="red", style="bold")
        elseif link_type == "valve"
            println("valves not yet implemented")
        else # it is a pipe
            length = @sprintf("%2.2g", link["length"])
            type = link["status"]
            if type != "Open"
                G.add_edge(link["node_fr"], link["node_to"], link["index"],
                           label=type*"\n"*length)
            else
                G.add_edge(link["node_fr"], link["node_to"], link["index"], label=length)
            end
        end
    end
end


""" 
Write out to a file a visualization for a WaterModels network dictionary parsed from an
EPANET file. `basefilename` should not include an extension and will be appended with
`_w_cb.pdf` in the final output file, which is a multi-page PDF. Use `del_files=false` to
keep the intermediate files.
"""
function write_visualization(data::Dict{String,Any}, basefilename::String;
                             del_files::Bool=true)
    # TODO:
    # - pass through arguments to `write_graph`

    #gvfile = basefilename*".gv"
    pdffile = basefilename*".pdf"
    cbfile = basefilename*"_cbar.pdf"
    outfile = basefilename*"_w_cb.pdf"
    
    G = build_graph(data)
    write_graph(G, pdffile)
    colorbar(G, cbfile)

    # add option -dAutoRotatePages=/None ?
    run(`gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$outfile $cbfile $pdffile`)
    # delete the intermediate files
    if del_files
        run(`rm $pdffile $cbfile`)
    end
end


"""
Use graphviz (via pygraphviz) to output a visualization to a file for a graph
"""
function write_graph(G::PyCall.PyObject, filename::String)
    # TODO:
    # - allow different graphviz programs to be used, e.g., neato
    # - allow other arguments to be passed through to graphviz
    G.draw(filename, prog="dot")
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
