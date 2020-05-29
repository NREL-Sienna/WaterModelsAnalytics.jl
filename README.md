# WaterModelsAnalytics.jl


WaterModelsAnalytics.jl is a Julia package to to support WaterModels.jl (and
possibly WaterSystems.jl) with network graph visualizations (and possibly other
graphics at a later version).

Currently requires Python's networkx and graphviz dot command.

Basic working example:

```
# import python's networkx-- must do this first due to a bug with PyCall,
# networkx and JuMP
import PyCall
nx = PyCall.pyimport("networkx")

import WaterModels
const WM = WaterModels
import WaterModelsAnalytics
const WMA = WaterModelsAnalytics

# change as needed, or use pathof(WaterModels)
basepath = "../../related_repos/WaterModels.jl/"
data = WM.parse_file(basepath*"test/data/epanet/van_zyl.inp")

WMA.write_visualization(data, "test")
```
