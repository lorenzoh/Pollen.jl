include("../imports.jl")


@testset "DocumentFolder" begin
    dir = Path(mktempdir())
    try
        write(joinpath(dir, "hi.md"), "Hello")
        rewriter = DocumentFolder(dir)

        docs = createsources!(rewriter)
        @test haskey(docs, p"hi.md")
        @test tag(docs[p"hi.md"]) == :body

        ch = Channel()
        fw = geteventsource(rewriter, ch)
        Pollen.start(fw)
        open(joinpath(dir, p"hi.md"), "w") do f
            write(f, "Hello")
        end
        event = take!(ch)
        @test event.name == p"hi.md"
        @test Pollen.gettext(event.doc) == "Hello"
        Pollen.stop(fw)
    catch e
        rethrow(e)
    finally
        rm(dir; recursive=true)
    end
end
