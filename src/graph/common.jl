# TODO:
# - parse for discrete valves and add labels for those links (valves as part of pipes are
#   done)
# x parse for demand at nodes and add demand labels
# x add fill color for each node that scales with elevation
# x add colorbar for elevation colors (how to do it?)
# - add an indication of edge length
# - add coordinates for the nodes and allow user to choose an output style that uses
#   coordinates


"""
Build networkx graph object from a WaterModels network dictionary parsed from an EPANET file.
"""
function build_graph(data::Dict{String,Any})
    # presumes input is data dict from WaterModels.parse_file()

    # TODO:
    # - check that input dictionary has the expected fields
    
    G = nx.MultiDiGraph()

    add_nodes!(G, data["node"])
    demand!(G, data["junction"])
    
    add_links!(G, data["pipe"])
    add_links!(G, data["pump"])
    add_links!(G, data["valve"])
    
    return G
end # funtion build_graph


function add_nodes!(G::PyCall.PyObject, nodes::Union{Dict{String,Any}, Dict{Int64,Any}})
    # TODO:
    # - use time-series information for reservoir (if it exists) to set the reservoir
    #   elevation

    # determine max and min elevations 
    elmin = 1e16 
    elmax = 1e-16
    for (key,node) in nodes
        elmin = min(elmin, node["elevation"])
        elmax = max(elmax, node["elevation"])
    end
    # add elmin and elmax as graph attributes for use in creating a colorbar in
    # colorbar (or via write_visualization)
    PyCall.set!(G."graph", "elmin", elmin)
    PyCall.set!(G."graph", "elmax", elmax)
    
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

        G.add_node(node["index"], label=name, elevation=elev, style="filled",
                   fillcolor=clrstr, fontcolor=fntclr)
    end
end


""" Add demand label for junctions."""
function demand!(G::PyCall.PyObject, junctions::Union{Dict{String,Any}, Dict{Int64,Any}})
    for (key,junction) in junctions
        #### are the keys in data["node"] alwyas equal to string(index) ??? will
        #### presume so for now, JJS 7/7/20
        if typeof(key) == String
            index = parse(Int, key)
        else
            index = key
        end
        name = get(G.nodes, index)["label"]
        #dem = @sprintf("%2.2g", mean(junction["demand"])) # not applicable for model network
        dem = @sprintf("%2.2g", junction["demand"])
        PyCall.set!(get(G."nodes", PyObject, index), "label", name*"\nd = "*dem)
    end
end


function add_links!(G::PyCall.PyObject, links::Union{Dict{String,Any}, Dict{Int64,Any}})
    for (key,link) in links
        link_type = link["source_id"][1]
        if link_type == "pump"
            G.add_edge(link["node_fr"], link["node_to"], link["index"],
                       label="P "*link["name"], color="red", style="bold")
        elseif link_type == "valve"
            println("valves not yet implemented")
        else # it is a pipe
            type = link["status"]
            if type != "Open"
                G.add_edge(link["node_fr"], link["node_to"], link["index"], label=type)
            else
                G.add_edge(link["node_fr"], link["node_to"], link["index"])
            end
        end
    end
end



"""
Build networkx graph object from a WaterModels network "ref" object 
"""
function build_graph(modnet::Dict{Symbol,Any})
    G = nx.MultiDiGraph()

    add_nodes!(G, modnet[:node])
    demand!(G, modnet[:junction])
    
    add_links!(G, modnet[:pipe])
    add_links!(G, modnet[:check_valve])
    add_links!(G, modnet[:shutoff_valve])
    add_links!(G, modnet[:pump])
    add_links!(G, modnet[:valve])
    
    return G
end


"""
Write out to a file a visualization for a WaterModels network dictionary parsed from an
EPANET file.
"""
function write_visualization(data::Union{Dict{String,Any}, Dict{Symbol,Any}},
                             basefilename::String, del_files::Bool=true)
    gvfile = basefilename*".gv"
    pdffile = basefilename*".pdf"
    cbfile = basefilename*"_cbar.pdf"
    outfile = basefilename*"_w_cb.pdf"
    
    G = build_graph(data)
    run_dot(G, gvfile)
    colorbar(G, cbfile)

    # add option -dAutoRotatePages=/None ?
    run(`gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$outfile $cbfile $pdffile`)
    # delete the intermediate files
    if del_files
        run(`rm $gvfile $pdffile $cbfile`)
    end
end


"""
Write a graph out to a file in graphviz dot syntax.
"""
function write_dot(G::PyCall.PyObject, filename::String)
    nx.nx_agraph.write_dot(G, filename)
end


"""
Run graphviz command `dot` on a graphviz file
"""
function run_dot(filename::String)
    # TODO:
    # - check that the filename ends in `.gv`
    # - allow specification of output filename
    # - allow arguments to be passed through to dot, such as the output file format
    
    basename = filename[1:end-3]
    outfile = basename*".pdf"
    run(`dot -Tpdf $filename -o $outfile`)
end


"""
Use graphviz command `dot` to output a visualization to a file for a graph
"""
function run_dot(G::PyCall.PyObject, filename::String)
    # TODO:
    # - pass additional arguments through to run_dot(filename)
    
    write_dot(G, filename)
    run_dot(filename)
end


"""
create and save a colorbar that represents the node elevations
"""
function colorbar(G::PyCall.PyObject, filename::String)
    elmin = G.graph["elmin"]
    elmax = G.graph["elmax"]
    elmid = elmin + (elmax-elmin)/2
    
    x = reshape(collect(range(0, 1, length=100)), (1,:))
    Plots.heatmap(x, c=:viridis, size=(500,100), legend=:none, yaxis=false)
    Plots.plot!(xticks=(0:50:100, [elmin, elmid, elmax]))
    Plots.title!("Elevation")
    Plots.savefig(filename)
end
