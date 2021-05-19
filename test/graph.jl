@testset "src/graph/graph.jl|output.jl" begin
    @testset "write_visualization" begin
        tmp_directory = mktempdir()
        write_visualization(network, joinpath(tmp_directory, "van_zyl"), del_files = false)
        @test isfile(joinpath(tmp_directory, "van_zyl_graph.pdf"))
        @test isfile(joinpath(tmp_directory, "van_zyl_cbar.pdf"))
        @test isfile(joinpath(tmp_directory, "van_zyl_graph_w_cb.pdf"))
        write_multi_time_viz(network_mn, solution, joinpath(tmp_directory, "van_zyl_wm"))
        @test isfile(joinpath(tmp_directory, "van_zyl_wm_graph_w_cb.pdf"))
        rm(tmp_directory, recursive = true)
    end
end
