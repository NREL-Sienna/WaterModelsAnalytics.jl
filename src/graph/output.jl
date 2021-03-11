
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
function write_graph(G::PyCall.PyObject, filename::String, layout::String="dot",
                     args::String="")
    # TODO:
    # - allow other arguments to be passed through to graphviz; how does pygraphviz handle passing of an empty string?
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
    Plots.savefig(filename)
end
