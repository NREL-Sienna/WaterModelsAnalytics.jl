# WaterModelsAnalytics.jl

WaterModelsAnalytics.jl is a Julia package to to support WaterModels.jl (and
possibly WaterSystems.jl) with network graph visualizations (and possibly other
graphics at a later version).

Currently requires Python's pygraphviz and graphviz dot command.

Basic working example:

```
import WaterModels
const WM = WaterModels
import WaterModelsAnalytics
const WMA = WaterModelsAnalytics

# change as needed, or use pathof(WaterModels)
basepath = "../../related_repos/WaterModels.jl/" 
data = WM.parse_file(basepath*"test/data/epanet/van_zyl.inp")
wm = WM.instantiate_model(data, WM.MICPWaterModel, WM.build_wf,
                          ext=Dict(:pump_breakpoints=>0))

WMA.write_visualization(data, "epanet_graph")

modnet = wm.ref[:nw][0]
WMA.write_visualization(modnet, "wm_graph")

```
