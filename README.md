# WaterModelsAnalytics.jl
<a href="https://travis-ci.org/NREL-SIIP/WaterModelsAnalytics.jl"><img src="https://travis-ci.org/NREL-SIIP/WaterModelsAnalytics.jl.svg?branch=master" align="top" alt="Development Build Status"></a> <a href="https://codecov.io/gh/NREL-SIIP/WaterModelsAnalytics.jl"><img align="top" src="https://codecov.io/gh/NREL-SIIP/WaterModelsAnalytics.jl/branch/master/graph/badge.svg" alt="Code Coverage Status"></a>

WaterModelsAnalytics.jl is a Julia package to to support WaterModels.jl (and
possibly WaterSystems.jl) with visualizations and solution validations. Current functionality includes:
- network graph visualizations
- plotting of pump curves for pumps in the network
- feasibility validation of optimal solutions (using WNTR/EPANET)

In addition to Julia package dependencies (captured in Project.toml), Python and the following modules are required (along with their sub-dependencies):
- pygraphviz (>=1.5)
- PyPDF2 (>=1.26.0)
- wntr (>=0.3.0)

And also the program **graphviz** (specifically `dot`) to write out the graph visualization files.

Basic working example for graph visualization:

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

WMA.write_visualization(data, "van_zyl_wm")
```
