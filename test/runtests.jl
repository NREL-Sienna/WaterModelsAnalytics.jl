using WaterModelsAnalytics

import Memento

import Gurobi
import JSON
import JuMP
import WaterModels
import PyCall

const _WM = WaterModelsAnalytics._WM
const _IM = WaterModelsAnalytics._WM._IM
const _MOI = WaterModelsAnalytics._WM._MOI




# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(_IM), "error")
Memento.setlevel!(Memento.getlogger(_WM), "error")
WaterModelsAnalytics.logger_config!("error")

using Test

# Setup common test data paths (from dependencies).
wm_path = joinpath(dirname(pathof(_WM)), "..")

@testset "WaterModelsAnalytics" begin

    include("graph.jl")

    include("io.jl")

    include("simulation.jl")
    include("validation.jl")

end
