"""
Functions to create graph visualizations of WNTR networks
"""

## TODO:
# - [nothing at the moment, JJS 1/25/21]

import numpy as np
import wntr
import networkx as nx
import pandas as pd 
import warnings
import matplotlib
from matplotlib import cm, colors, colorbar, pyplot
import PyPDF2
import os


def build_graph(wn, time=1, wnsol=None):
    """
    Build pygraphviz graph from a WNTR network object parsed from an inp file.

    `time` is presumed to be integer hours

    `wnsol`, if provided, should be a WNTR solution dict generated via `run.sim()` 
    """    

    # create the graph
    Gnx = wn.get_graph() # networkx object; more features and functions

    node_attrs(wn, Gnx, time)
    link_attrs(wn, Gnx)
    if wnsol is not None:
        add_solution(wn, Gnx, wnsol, time)

    return nx.nx_agraph.to_agraph(Gnx)


def node_attrs(wn, Gnx, time):
    """
    Add/change node attributes suitable for visualization
    """
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
        if res.head_timeseries.pattern is None:
            res_elevs[node] = res.head_timeseries.base_value
        else:
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
    return


def link_attrs(wn, Gnx):
    """
    Add/change link attributes suitable for visualization
    """
    # loop over controls to find pipes with shutoff valves
    sv_name_list = []
    for control in wn.controls():
        link = control[1].actions()[0].target()[0]
        if link.link_type == "Pipe":
            if link.name not in sv_name_list:
                sv_name_list.append(link.name)
    # loop over links that have a closed status to find closed pipes; will
    # presume these could be controllable by shutoff valves, even if controls
    # are not specified in the inp file
    status = wn.query_link_attribute("status")
    closed = status[status == 0]
    for name in closed.index:
        link = wn.get_link(name)
        if link.link_type == "Pipe":
            if link.name not in sv_name_list:
                sv_name_list.append(link.name)
    
    # loop over links to set graphviz attributes
    # (note: `list(Gnx.edges)` provides a list of the edge keys)
    for edge in Gnx.edges:
        eatts = Gnx.edges.get(edge)
        link = wn.get_link(edge[2])
        if eatts['type'] == 'Pump':
            eatts['color'] = 'red'
            eatts['style'] = 'bold'
            eatts['label'] = "Pmp\n" + edge[2]
        elif eatts['type'] == 'Valve': # these are special-type valves, e.g., PRVs
            #link = wn.get_link(edge[2]) # oops, I think this is redundant, will delete
            eatts['color'] = 'purple' # what is a good eye-catching color?
            eatts['style'] = 'bold'
            eatts['label'] = link.valve_type + "\n" + edge[2]
        # wn._check_valves is no longer in wntr-0.4.1 JJS 3/3/22
        #elif edge[2] in wn._check_valves:
        elif link.check_valve:
            length = "%2.2g m" % link.length
            eatts['label'] = "CV\n" + edge[2] + "\n" + length
        elif edge[2] in sv_name_list:
            length = "%2.2g m" % link.length
            eatts['label'] = "SV\n" + edge[2] + "\n" + length
        else:
            length = "%2.2g m" % link.length
            eatts["label"] = edge[2] + "\n" + length
    return


def add_solution(wn, Gnx, wnsol, time):
    """
    Add head and flowrates to the labels for nodes and links, respectively.
    """
    # add head to the node labels (could alternatively show pressure)
    node_results = wnsol.node
    head = node_results["head"]
    for node in Gnx.nodes:
        natts = Gnx.nodes.get(node)
        headval = _val_string_cut(head[node].iloc[time], 1e-10)
        if "label" in natts:
            natts["label"] += "\nh: " + headval
        else:
            natts["label"] = node + "\nh: " + headval
    link_results = wnsol.link
    flowrate = link_results["flowrate"]
    for link in Gnx.edges:
        flowval = _val_string_cut(flowrate[link[2]].iloc[time], 1e-10)
        latts = Gnx.edges.get(link)
        latts["label"] += "\nq: " + flowval
    return


def _val_string_cut(val, cut):
    if val < cut:
        return "0"
    else:
        return "%2.2g" % val


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
    return


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
    return


def stack_cbar(graphfilename, cbfilename, outfilename, sep_page=False):
    """
    Stack the colorbar on top of the graph using PyPDF2. Use `sep_page=True` to
    have the colorbar on a separate page (faster processing for large graphs).
    """
    
    # use PyPDF2 to merge the colorbar
    input1 = PyPDF2.PdfFileReader(open(graphfilename, "rb"))
    input2 = PyPDF2.PdfFileReader(open(cbfilename, "rb"))

    output = PyPDF2.PdfFileWriter()

    page1 = input1.getPage(0)
    page2 = input2.getPage(0)
    if sep_page: # set colorbar to be first page
        output.addPage(page2)
        output.addPage(page1)
    else: # merge the colorbar
        h1 = page1.mediaBox.getHeight()
        w1 = page1.mediaBox.getWidth()
        h2 = page2.mediaBox.getHeight()
        w2 = page2.mediaBox.getWidth()
        w = max(w1,w2)
        h = h1 + h2
        newpage = PyPDF2.pdf.PageObject.createBlankPage(None, w, h)
        # the coordinates are referenced to lower-left
        if w2>w1:
            newpage.mergeScaledTranslatedPage(page1, 1, (w2-w1)/2, 0)
            newpage.mergeScaledTranslatedPage(page2, 1, 0, h1) 
        else:
            newpage.mergeScaledTranslatedPage(page1, 1, 0, 0)
            newpage.mergeScaledTranslatedPage(page2, 1, (w1-w2)/2, h1)
        output.addPage(newpage)
 
    outfile = open(outfilename, "wb")
    output.write(outfile)
    outfile.close()
    return


def collate_viz(filenames, outfilename):
    """
    Collate the pages of a multi-time visualization. 
    """
    output = PyPDF2.PdfFileWriter()
    for filename in filenames:
        inpdf = PyPDF2.PdfFileReader(open(filename, "rb"))
        page = inpdf.getPage(0)
        output.addPage(page)

    outfile = open(outfilename, "wb")
    output.write(outfile)
    outfile.close()
    return
    

def write_visualization(wn, basefilename, time=1, wnsol=None, layout="dot",
                        sep_page=False, del_files=True):
    """
    Write out to a file a visualization for an Epanet network dictionary
    parsed from an EPANET file. `basefilename` should not include an extension
    and will be appended with `_w_cb.pdf` in the final output file, which is a
    multi-page PDF. The `layout` option equates to the layout functions of
    graphviz (dot, neato, etc.). Use `sep_page=True` to have the colorbar on a
    separate page (faster processing for large graphs). Use `del_files=False`
    to keep the intermediate files.

    `time` is presumed to be integer hours

    `wnsol`, if provided, should be a WNTR solution dict generated via `run.sim()` 

    """
    graphfile = basefilename + "_graph.pdf"
    cbfile = basefilename + "_cbar.pdf"
    outfile = basefilename + "_w_cb.pdf"

    G = build_graph(wn, time, wnsol)
    write_graph(G, graphfile, layout)
    write_cbar(G, cbfile)

    stack_cbar(graphfile, cbfile, outfile, sep_page)
    
    if del_files:
        os.remove(graphfile)
        os.remove(cbfile)
    return
