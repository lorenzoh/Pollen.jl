include("imports.jl")

@testset "changehrefextension" begin
    ext = "html"
    @test changehrefextension("./hello.md", ext) == "./hello.md.html"
    @test changehrefextension("#", ext) == "#"
    @test changehrefextension("#id", ext) == "#id"
    @test changehrefextension("/root/bla#id", ext) == "/root/bla.html#id"
    @test_broken changehrefextension("/root/bla.blub.bab#id", ext) == "/root/bla.blub.bab.html#id"
end
