include("imports.jl")


@testset "Pollen.jl" begin
    @testset ExtendedTestSet "HTML" begin
        format = HTML()
        @test_nowarn Pollen.parse("<h1>Hello World!</h1>", format)
    end

    @testset ExtendedTestSet "Markdown" begin
        format = Markdown()
        @test_nowarn Pollen.parse("# Hello World!", format)
    end

    include("fileutils.jl")
end
