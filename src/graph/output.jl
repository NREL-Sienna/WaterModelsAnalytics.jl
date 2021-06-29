
""" 
    write_visualization(data, basefilename, solution=nothing;
                        layout="dot", args="", sep_page=false, del_files=true)

Write out to a file a visualization for a WaterModels network dictionary parsed from an
EPANET file. `basefilename` should not include an extension and will be appended with
`_w_cb.pdf` in the final output file, which is a multi-page PDF. The `layout` option equates
to the layout functions of graphviz (dot, neato, etc.). Use `del_files=false` to keep the
intermediate files. If a `solution` dict is provided, it should be for the same time as that
of the `data` dict.
"""
function write_visualization(data::Dict{String,Any}, basefilename::String,
                             solution::Union{Nothing, Dict{String,Any}}=nothing;
                             layout::String="dot", args::String="",
                             sep_page::Bool=false, del_files::Bool=true)

    gpdffile = basefilename*"_graph.pdf"
    cbfile = basefilename*"_cbar.pdf"
    outfile = basefilename*"_graph_w_cb.pdf"
    
    G = build_graph(data, solution, layout=layout, args=args)
    write_graph(G, gpdffile)
    colorbar(G, cbfile)

    # note that `stack_bar` is a python function from `wntr_vis.py`
    stack_cbar(gpdffile, cbfile, outfile, sep_page)
    
    # delete the intermediate files
    if del_files
        run(`rm $gpdffile $cbfile`)
    end
end


""" 
    write_multi_time_viz(wmdata, solution, basefilename;
                         layout="dot", args="", del_files=true)

Create a visualizations for each time. `wmdata` and `solution` are multi-time WM data
objects.
"""
function write_multi_time_viz(wmdata::Dict{String,Any}, solution::Dict{String,Any},
                              basefilename::String; layout::String="dot", args::String="",
                              del_files::Bool=true)
    cbfile = basefilename*"_cbar.pdf"
    outfile = basefilename*"_graph_w_cb.pdf"
    
    duration = wmdata["duration"]/3600
    step = wmdata["time_step"]/3600
    tarr = collect(range(1, stop=duration, step=step))  
    tarr = string.(Int.(tarr))
    N = length(tarr)

    k = 0
    filenames = Array{String,1}(undef, N+1)
    filenames[k+=1] = cbfile
    
    # build graph at t = 1
    t = tarr[1]
    G = build_graph(wmdata["nw"][t], solution["nw"][t], layout=layout, args=args)
    filename = "$(basefilename)_$(t)_graph.pdf"
    write_graph(G, filename)
    filenames[k+=1] = filename
    
    # loop over remaining timepoints
    for t in tarr[2:end]
        update_graph!(G, wmdata["nw"][t], solution["nw"][t])
        filename = "$(basefilename)_$(t)_graph.pdf"
        write_graph(G, filename)
        filenames[k+=1] = filename
    end

    colorbar(G, cbfile)

    # collate the pages
    collate_viz(filenames, outfile)

    # delete files
    if del_files
        for filename in filenames
            run(`rm $filename`)
        end
    end
end


"""
    write_graph(G, filename, layout=nothing, args=nothing)

Use graphviz (via pygraphviz) to output a visualization to a file for a graph.

The layout may be redone here but will add computational cost. Note that absolute coordinate
layouts (`neato -n`) will likely not work here as the coordinates were overwritten during the
call to `build_graph`.
"""
function write_graph(G::PyCall.PyObject, filename::String,
                     layout::Union{Nothing, Dict{String, <:Any}} = nothing,
                     args::Union{Nothing, Dict{String, <:Any}} = nothing)
    
    if layout == nothing
        G.draw(filename) # uses layout that was already created in `build_graph`
        if args != nothing
            @warn "args are ignored if a layout is not given"
        end
    else
        try
            G.draw(filename, prog=layout)
        catch
            G.draw(filename, prog="dot")
            # by putting this warning after, it should display only if `G.draw()` was
            # actually successful using "dot"; if it fails for another reason, that error
            # should be shown
            @warn "$layout is not a supported layout; dot was used instead"
        end
    end
end


# FIXME:  change this to _colorbar()
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
