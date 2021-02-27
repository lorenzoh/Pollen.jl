using Pollen
using Pollen: Markdown, HTML, xexpr
using Test
using TestSetExtensions


@testset "Pollen.jl" begin
    @testset ExtendedTestSet "HTML" begin
        format = HTML()
        @test_nowarn Pollen.parse("<h1>Hello World!</h1>", format)
    end

    @testset ExtendedTestSet "Markdown" begin
        format = Markdown()
        @test_nowarn Pollen.parse("# Hello World!", format)
    end
end
