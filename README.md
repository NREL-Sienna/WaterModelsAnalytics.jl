# WaterModelsAnalytics.jl
[![Build Status](https://github.com/NREL-SIIP/WaterModelsAnalytics.jl/workflows/CI/badge.svg?branch=master)](https://github.com/NREL-SIIP/WaterModelsAnalytics.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/NREL-SIIP/WaterModelsAnalytics.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/NREL-SIIP/WaterModelsAnalytics.jl)

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
