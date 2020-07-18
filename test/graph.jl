@testset "src/graph/common.jl" begin
    @testset "build_graph" begin
        data = _WM.parse_file("$(wm_path)/test/data/epanet/van_zyl.inp")
        write_visualization(data, "van_zyl_graph")
    end
end
