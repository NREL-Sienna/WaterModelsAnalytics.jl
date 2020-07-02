# TODO:
    # - parse for valves and add labels for those links
    # - parse for demand at nodes and add demand labels
    # x add fill color for each node that scales with elevation
    # - add colorbar for elevation colors (how to do it?)
    # - add coordinates for the nodes and allow user to choose an output style that uses
    #   coordinates


# heatmap([2D-array], c=:viridis)

"""
Build networkx graph object from a WaterModels network dictionary parsed from an EPANET file.
"""
function build_graph(data::Dict{String,Any})
    # presumes input is data dict from WaterModels.parse_file()

    # TODO:
    # - check that input dictionary has the expected fields
    
    G = nx.MultiDiGraph()

    # populate the graph with water network data
    add_nodes!(G, data["node"])

      
    add_links!(G, data["pipe"])
    add_links!(G, data["pump"])
    add_links!(G, data["valve"])
    
    return G
end # funtion build_graph


function add_nodes!(G::PyCall.PyObject, nodes::Dict{String,Any})

    #### FIXME: change the approach: loop through the elevations of the nodes to get elmin
    #### and elmax; _then_ do the loop to create the nodes with the desired attributes (it
    #### is difficult to change/add node attributes once the node has been added)

    # determine max and min elevations 
    elmin = 1e6 # is this high enough?
    elmax = 0
    for (key,node) in nodes
        elmin = min(elmin, node["elevation"])
        elmax = max(elmax, node["elevation"])
    end
    elspan = elmax - elmin
    #scaled_elev = (elevs .- minimum(elevs))./(maximum(elevs) - minimum(elevs))
    #collect(values(elevs))
    
    # parse elevations of each node and assign a color based on a color scheme (viridis)
    #import ColorSchemes
    #ColorSchemes.viridis[scaled_elev]
    # or
    #import ColorSchemes.viridis # this is done now in WaterModelsAnalytics.jl, JJS 6/30/20
    #viridis[scaled_elev]
    # not sure how to loop over G.nodes and add more attributes for the color

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
        #scaled_elev = (elev - elmin)/elspan
        #clr  = get(viridis, scaled_elev)
        clr = HSV(get(viridis, elev, (elmin, elmax)))
        # convert clr to a string
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

function add_links!(G::PyCall.PyObject, links::Dict{String,Any})
    for (key,link) in links
        link_type = link["source_id"][1]
        if link_type == "pump"
            G.add_edge(link["node_fr"], link["node_to"], link["index"],
                       label="P "*link["name"], color="red", style="bold")
        else
            G.add_edge(link["node_fr"], link["node_to"], link["index"])
        end
    end
end


"""
Write out to a file a visualization for a WaterModels network dictionary parsed from an
EPANET file.
"""
function write_visualization(data::Dict{String,Any}, basefilename::String)
    G = build_graph(data)
    run_dot(G, basefilename*".gv")
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
    # - allow specification of output filename
    # - allow arguments to be passed through to dot, such as the output file format
    # - check that the filename ends in `.gv`
    
    basename = filename[1:end-3]
    outfile = basename*".pdf"
    run(`dot -Tpdf $filename -o $outfile`)
end


"""
Use graphviz command `dot` to output a visualization to a file for a graph
"""
function run_dot(G::PyCall.PyObject, filename::String)
    # TODO:
    # - provide an option to delete the intermediate .gv file
    # - pass additional arguments through to run_dot(filename)
    
    write_dot(G, filename)
    run_dot(filename)
end




# """
# Build networkx graph object from a WaterModels network ref object -- TBD
# """
# function build_graph(data::Dict{Symbol,Any})

# end
