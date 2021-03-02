include("imports.jl")

@testset ExtendedTestSet "changehrefextension" begin
    ext = "html"
    @test changehrefextension("./hello.md", ext) == "./hello.html"
    @test changehrefextension("#", ext) == "#"
    @test changehrefextension("#id", ext) == "#id"
    @test changehrefextension("/root/bla#id", ext) == "/root/bla.html#id"
    @test changehrefextension("/root/bla.blub.bab#id", ext) == "/root/bla.blub.html#id"
end
