include("imports.jl")


@testset "Pollen.jl" begin
    @testset "HTML" begin
        format = HTML()
        @test_nowarn Pollen.parse("<h1>Hello World!</h1>", format)
    end

    @testset "Markdown" begin
        format = Markdown()
        @test_nowarn Pollen.parse("# Hello World!", format)
    end

    include("fileutils.jl")
    include("catas.jl")
    include("references.jl")
    include("xtree.jl")
    include("selectors.jl")
    include("server.jl")
    include("rewriters/documentfolder.jl")
end
