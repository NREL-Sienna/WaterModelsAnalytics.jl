@testset "src/graph/common.jl" begin
    @testset "write_visualization" begin
        data = _WM.parse_file("$(wm_path)/examples/data/epanet/van_zyl.inp")
        tmp_directory = mktempdir()
        println(tmp_directory)
        write_visualization(data, joinpath(tmp_directory, "van_zyl"), del_files = false)
        @test isfile(joinpath(tmp_directory, "van_zyl_graph.pdf"))
        @test isfile(joinpath(tmp_directory, "van_zyl_cbar.pdf"))
        @test isfile(joinpath(tmp_directory, "van_zyl_w_cb.pdf"))
        rm(tmp_directory, recursive = true)
    end
end
