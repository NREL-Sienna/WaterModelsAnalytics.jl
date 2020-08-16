# WaterModelsAnalytics.jl

WaterModelsAnalytics.jl is a Julia package to to support WaterModels.jl (and
possibly WaterSystems.jl) with network graph visualizations (and possibly other
graphics at a later version).

Currently requires Python's `pygraphviz` and the graphviz `dot` command.

Basic working example:

```julia
import InfrastructureModels
const IM = InfrastructureModels
import WaterModels
const WM = WaterModels
import WaterModelsAnalytics
const WMA = WaterModelsAnalytics

basepath = dirname(dirname(pathof(WaterModels)))
data = WM.parse_file(joinpath(basepath, "test/data/epanet/van_zyl.inp"))
IM.load_timepoint!(data, 1)

WMA.write_visualization(data, "epanet_graph")
```
