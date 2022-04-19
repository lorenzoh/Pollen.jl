include("imports.jl")


@testset "Server updates" begin
    server = testserver()
    @test_nowarn addsource!(server, p"hello.md", Node(:body, [Leaf("Hello")]))
    @test_nowarn addrewrite!(server, p"hello.md")
    @test_nowarn addbuild!(server, p"hello.md")
    @test !haskey(server.project.sources, p"hello.md")
    @test_nowarn applyupdates!(server)
    @test haskey(server.project.sources, p"hello.md")
    @test haskey(server.project.outputs, p"hello.md")
    @test isfile(joinpath(server.builder.dir, p"hello.md.html"))
end


@testset "FileServer" begin
    dir = Path(mktempdir())
    fs = FileServer(dir)
    start(fs)
    stop(fs)
end


@testset "ServeFiles" begin
    server = testserver()
    mode = ServeFiles()
    @test geteventsource(mode, server, Channel()) isa Pollen.FileServer
end

@testset "ServeFilesLazy" begin
    server = testserver()
    mode = ServeFilesLazy()
    @test geteventsource(mode, server, Channel()) isa Pollen.FileServer
end


@testset "servereventsources" begin
    server = testserver()
    mode = ServeFiles()
    @test Pollen.servereventsources(server, mode, Channel()) |> length == 2
end
