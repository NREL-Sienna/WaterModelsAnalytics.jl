@testset "src/graph/common.jl" begin
    @testset "build_graph" begin
        data = _WM.parse_file("$(wm_path)/examples/data/epanet/van_zyl.inp")
        tmp_directory = mktempdir()
        write_visualization(data, "$(tmp_directory)/van_zyl", del_files = false)
        @test isfile("$(tmp_directory)/van_zyl_graph.pdf")
        @test isfile("$(tmp_directory)/van_zyl_cbar.pdf")
        @test isfile("$(tmp_directory)/van_zyl_w_cb.pdf")
        rm(tmppth, recursive = true)
    end
end
