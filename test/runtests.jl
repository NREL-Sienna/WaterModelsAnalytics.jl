## tests todo (also see https://github.com/NREL-SIIP/WaterModelsAnalytics.jl/issues/6):
# - create graph of Epanet network parsed by WNTR with Python-only code (python/wntr_vis.py)
# - plots/pumps.jl (this should also use code in analysis/pump_bep.jl and utility.jl)

using WaterModelsAnalytics

import Memento
import JSON

#import PyCall # will likely use this to test python code

const _WM = WaterModelsAnalytics._WM
const _IM = WaterModelsAnalytics._WM._IM
const _MOI = WaterModelsAnalytics._WM._MOI


# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(_IM), "error")
Memento.setlevel!(Memento.getlogger(_WM), "error")
WaterModelsAnalytics.logger_config!("error")

using Test

include("common.jl")

@testset "WaterModelsAnalytics" begin

    include("graph.jl")

    # empty test, so just a placeholder
    include("io.jl")

    include("simulation.jl")
    include("validation.jl");
end
