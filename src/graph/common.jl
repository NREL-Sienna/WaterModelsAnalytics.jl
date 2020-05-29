"""
Build networkx graph object from a WaterModels network dictionary parsed from an EPANET file.
"""
function build_graph(data::Dict{String,Any})
    # presumes input is data dict from WaterModels.parse_file()

    # TODO:
    # - check that input dictionary has the expected fields
    # - parse for valves and add labels for those links
    # - parse for demand at nodes and add demand labels
    # - add fill color for each node that scales with elevation
    # - add coordinates for the nodes and allow user to choose an output style that uses
    #   coordinates
    
    G = nx.MultiDiGraph()

    # populate the graph with water network data
    add_nodes!(G, data["node"])

      
    add_links!(G, data["pipe"])
    add_links!(G, data["pump"])
    add_links!(G, data["valve"])
    
    return G
end # funtion build_graph


function add_nodes!(G::PyCall.PyObject, nodes::Dict{String,Any})
    elevs = zeros(nodes.count)
    for (i,(key,node)) in enumerate(nodes)
        node_type = node["source_id"][1]
        if node_type == "reservoir"
            name = "Rsvr\n"*node["name"]
        elseif node_type == "tank"
            name = "Tank\n"*node["name"]
        else
            name = node["name"]
        end
        G.add_node(node["index"], label=name, elevation=node["elevation"])
        elevs[i] = node["elevation"]
    end
    scaled_elev = (elevs .- minimum(elevs))./(maximum(elevs) - minimum(elevs))
    # parse elevations of each node and assign a color based on a color scheme (viridis)
    #import ColorSchemes
    #ColorSchemes.viridis[scaled_elev]
    # or
    #import ColorSchemes.viridis
    #viridis[scaled_elev]
    # not sure how to loop over G.nodes and add more attributes for the color
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
