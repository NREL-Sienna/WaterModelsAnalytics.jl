@testset "src/graph/common.jl" begin
    @testset "build_graph" begin
        data = _WM.parse_file("$(wm_path)/examples/data/epanet/van_zyl.inp")
        tmppth = mktempdir()
        write_visualization(data, "$(tmppth)/van_zyl_wm", del_files=false)
        @test isfile("$(tmppth)/van_zyl_wm_graph.pdf")
        @test isfile("$(tmppth)/van_zyl_wm_cbar.pdf")
        @test isfile("$(tmppth)/van_zyl_wm_graph_w_cb.pdf")
        rm(tmppth, recursive=true)
    end
end
