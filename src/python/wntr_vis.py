"""
Functions to create graph visualizations of WNTR networks
"""

## TODO:
# - display the length of links
# - display information from the network solution
# - process shutoff valves; rarely occur in networks we are looking to use...

import numpy as np
import wntr
import networkx as nx
#import pygraphviz as pgv
import pandas as pd 
import warnings
import matplotlib
from matplotlib import cm, colors, colorbar, pyplot
import subprocess


def build_graph(wn, time=1, wnsol=None):
    """
    Build pygraphviz graph from a WNTR network object parsed from an inp file.

    `time` is presumed to be integer hours

    `wnsol` is currently ignored [TBD]
    """    

    # # TBD: use the simulation results
    # link_results = wnsol.link
    # node_results = wnsol.node

    # create the graph
    Gnx = wn.get_graph() # networkx object; more features and functions

    # node position attributes (coordinates in inp file)
    pos = nx.get_node_attributes(Gnx, "pos")

    # adjust and convert position tuple to comma-delimited string with
    # exclamation point; not used with default dot layout
    xpos = np.array([pos[i][0] for i in pos.keys()])
    ypos = np.array([pos[i][1] for i in pos.keys()])
    xmin = xpos.min()
    xmax = xpos.max()
    xspan = xmax - xmin
    ymin = ypos.min()
    ymax = ypos.max()
    yspan = ymax-ymin

    # scale to use to get "good" position results with graphviz output --
    # calculate this systematically from the number of nodes?
    scale = 20

    # scale position and convert to string
    for node in Gnx.nodes:
        # convert position tuple to string (so that graphviz can actually use it!)
        postup = Gnx.nodes[node]["pos"]
        # during conversion to strings, adjust scale so that positions are reasonable
        xval = scale*(postup[0] - xmin)/xspan
        yval = scale*(postup[1] - ymin)/yspan
        posstr = str(xval) + "," + str(yval) 
        # add exclamation point to set fixed positions when using neato layout
        posstr += "!"
        Gnx.nodes[node]["pos"] = posstr
    
    # add label designations to reservoirs and tanks
    for rsvr in wn.reservoir_name_list: # usually just one, but could be more I suppose
        Gnx.nodes[rsvr]['label'] = "Rsvr\n" + rsvr
    for tank in wn.tank_name_list:
        Gnx.nodes[tank]['label'] = "Tank\n" + tank
    # highlight junctions with demand, using the time provided (or default of 1)
    based = wn.query_node_attribute('base_demand')
    idx = np.nonzero((based>1e-12).values)[0]
    demnodes = based.iloc[idx].index
    #demand = wn.query_node_attribute('base_demand')*1000 # L/s
    for nname in demnodes:
        node = wn.get_node(nname)
        pat = node.demand_timeseries_list.pattern_list()[0]
        demval = based[nname]*pat[time-1]
        Gnx.nodes[nname]['label'] = nname + "\nd = %2.2g" % demval

    ## add elevation information
    # presume that junctions and tanks have an "elevation" and reservoirs have a
    # "base head" (and not keys for both)
    elevs = wn.query_node_attribute('elevation')
    # use the time and the pattern and multiply by the base head
    res_elevs = wn.query_node_attribute('base_head')
    resnames = res_elevs.index.values
    for node in resnames:
        res = wn.get_node(node)
        mults = res.head_timeseries.pattern.multipliers
        # "base_value" should be the same as what was aleady queried by
        # "base_head", so either should work
        res_elevs[node] = res.head_timeseries.base_value * mults[time-1]
    
    elevs = pd.concat((elevs, res_elevs))
    elmin = elevs.min()
    elmax = elevs.max()
    # store max and min elevations as graph attributes to use for creating a colorbar
    Gnx.graph["elmin"] = elmin
    Gnx.graph["elmax"] = elmax
    
    nodenames = elevs.index.values
    elevsrel = (elevs - elmin)/(elmax - elmin)
    cmap = cm.get_cmap('viridis') # can make colormap a user option
    elevclrs = pd.DataFrame(colors.rgb_to_hsv(cmap(elevsrel)[:,:3]), index=nodenames)
    for node in nodenames:
        Gnx.nodes[node]['style'] = "filled"
        clr = np.array(elevclrs.loc[node])
        clrstr = np.array_str(clr)
        Gnx.nodes[node]['fillcolor'] = clrstr[1:-1] # remove brackets from string
        if clr[2] < 0.6:
            Gnx.nodes[node]["fontcolor"] = "white"
    
    # loop over edges -- really not sure if this is efficient or if there is a more
    # elegant way (can't seem to use link label alone; see comment below)
    for edge in Gnx.edges:
        eatts = Gnx.edges.get(edge)
        if eatts['type'] == 'Pump':
            eatts['color'] = 'red'
            eatts['style'] = 'bold'
            eatts['label'] = "Pmp\n" + edge[2]
        elif edge[2] in wn._check_valves:
            eatts['label'] = "CV\n" + edge[2]
        else:
            eatts["label"] = edge[2]
        # TODO:  process for shutoff valves  `wn._get_valve_controls()`

    return nx.nx_agraph.to_agraph(Gnx)


def write_graph(G, filename, layout="dot"):
    """ 
    Use graphviz (via pygraphviz) to output a visualization to a file for a graph. The
    `layout` option equates to the layout functions of graphviz (dot, neato, etc.).
    """
    try:
        G.draw(filename, prog=layout)
    except:
        G.draw(filename, prog="dot")
        warnings.warn("%s is not a supported layout; dot was used instead"%layout)
    

def write_cbar(G, filename):
    """
    make the colorbar for the elevations 
    """
    # https://matplotlib.org/tutorials/colors/colorbar_only.html
    # G.graph_attr.keys() # to see the attribute keys

    # if user's matplotlib environment is interactive, turn off
    interactive = matplotlib.is_interactive()
    if interactive:
        pyplot.ioff()

    fig = pyplot.figure(figsize=(6,1))
    ax = pyplot.gca()
    cmap = cm.viridis
    norm = colors.Normalize(vmin=G.graph_attr["elmin"], vmax=G.graph_attr["elmax"])
    cb1 = colorbar.ColorbarBase(ax, cmap=cmap, norm=norm, orientation='horizontal')
    cb1.set_label('Elevation [m]')
    pyplot.savefig(filename, bbox_inches='tight')
    pyplot.close(fig) # may not be necessary if not displaying the figure?
    # if user's matplotlib environment was interactive, turn back on
    if interactive:
        pyplot.ion()


def write_visualization(wn, basefilename, time=1, wnsol=None, layout="dot",
                        del_files=True):
    """
    Write out to a file a visualization for a WaterModels network dictionary
    parsed from an EPANET file. `basefilename` should not include an extension
    and will be appended with `_w_cb.pdf` in the final output file, which is a
    multi-page PDF. The `layout` option equates to the layout functions of
    graphviz (dot, neato, etc.). Use `del_files=False` to keep the intermediate
    files.

    `time` is presumed to be integer hours; `wnsol` is currently ignored [TBD]
    """
    # use ghostscript to make a 2-page pdf with the colorbar as the first page
    # -- I'd like to embed the colorbar in the graph page, but I don't know how
    # to do that yet, JJS 10/10/19
    # maybe this will do it?:  https://github.com/mstamy2/PyPDF2
    graphfile = basefilename + "_graph.pdf"
    cbfile = basefilename + "_cbar.pdf"
    outfile = basefilename + "_w_cb.pdf"

    G = build_graph(wn, time, wnsol)
    write_graph(G, graphfile, layout)
    write_cbar(G, cbfile)
    
    command = "gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -sOutputFile=" + outfile + " " + cbfile + " " + graphfile 
    subprocess.run(command.split())
    if del_files:
        # remove support files
        command = "rm " + cbfile + " " + graphfile
        subprocess.run(command.split())
