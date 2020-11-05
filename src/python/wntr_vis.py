"""
Functions to create graph visualizations of WNTR networks
"""

## TODO:
# * reduce digits of base demand printing
# * reservoir head: use reservoir head pattern and multiply by base elevation
# - process shutoff valves

import numpy as np
import wntr
import networkx as nx
import pygraphviz as pgv
import pandas as pd 
import warnings

from matplotlib import cm, colors
    
#from matplotlib import pyplot as plt
#ion()


def build_graph(wn, time=1, wnsol=None):
    """
    Build pygraphviz graph from a WNTR network object parsed from an inp file.

    `time` is presumed to be integer hours

    """    
    # wn_dict = wn.todict() # not used...

    # # TBD: use the simulation results
    # link_results = wnsol.link
    # node_results = wnsol.node

    # create the graph
    Gnx = wn.get_graph() # networkx object; more features and functions
    #Gpg = nx.nx_agraph.to_agraph(G) # pygraphviz object--use later     

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
        Gnx.nodes[nname]['label'] = nname + "\nd = %g" % demval

    ## add elevation information
    # presume that junctions and tanks have an "elevation" and reservoirs have a
    # "base head" (and not keys for both)
    elevs = wn.query_node_attribute('elevation')
    # I think this next line gets the base head for reservoirs---using it by itself
    # is useless if there is a pattern associated with the reservoir: TBD - use the
    # time and the pattern and multiply by the base head, JJS 1/28/19
    elevs = pd.concat((elevs, wn.query_node_attribute('base_head')))
    nodenames = elevs.index.values
    elevsrel = (elevs - elevs.min())/(elevs.max()-elevs.min())
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
    

#     # use ghostscript to make a 2-page pdf with the colorbar as the first page
#     # -- I'd like to embed the colorbar in the graph page, but I don't know how
#     # to do that yet, JJS 10/10/19
#     command = "gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -sOutputFile=" + outputfilebase + "_w_cb.pdf " + cbfile + " " + pdffile 
#     subprocess.run(command.split())
#     # remove support files -- provide an option to keep these !!!!!!!
#     command = "rm " + gvfile + " " + cbfile + " " + pdffile
#     subprocess.run(command.split())
    



    # #### put this in a separate function
    # # make the colorbar for the elevations -- not sure how best to integrate this with the graph
    # # https://matplotlib.org/tutorials/colors/colorbar_only.html
    # from matplotlib import colorbar

    # figure(1, figsize=(6,1))
    # clf()
    # ax = gca()
    # cmap = cm.viridis
    # norm = colors.Normalize(vmin=elevs.min(), vmax=elevs.max())
    # cb1 = colorbar.ColorbarBase(ax, cmap=cmap, norm=norm, orientation='horizontal')
    # cb1.set_label('Elevation [m]')
    # if graphoutput:
    #     cbfile = outputfilebase + "_colorbar.pdf"
    #     # something weird is happening with this in python 3.8 -- see if it persists, JJS 8/21/20
    #     savefig(cbfile, bbox_inches='tight')
