Base.@kwdef struct DocumentFolder <: Rewriter
    dirs::Vector{Pair{String, String}}
    filterfn = hasextension(["md", "ipynb"])
    formatfn = extensionformat
    files::Dict{String, FileLoader} = Dict{String, FileLoader}()
end

DocumentFolder(dirs::Vector; kwargs...) =
    DocumentFolder(; dirs = map(d -> d isa Pair ? d : "" => d, dirs), kwargs...)
DocumentFolder(dir::String; kwargs...) = DocumentFolder([dir]; kwargs...)


function createsources!(rewriter::DocumentFolder)
    sources = Dict{String, Node}()
    for (prefix, dir) in rewriter.dirs
        for file in filter(rewriter.filterfn, rglob("*", dir))
            docid = "$prefix$(relpath(file, dir))"

            # Skip if already created
            docid in keys(rewriter.files) && continue

            loadfn() = Pollen.parse(Path(file), rewriter.formatfn(file))
            rewriter.files[docid] = FileLoader(file, docid, loadfn)
            sources[docid] = loadfn()
        end
    end
    return sources
end


function reset!(rewriter::DocumentFolder)
    # Clear the dictionary with collected files, so they can be recreated
    empty!(rewriter.files)
end


function geteventhandler(rewriter::DocumentFolder, ch)
    return makefilewatcher(ch, rewriter.files, last.(rewriter.dirs))
end


function DocumentationFiles(ms::Module; extensions = ["md", "ipynb"], kwargs...)
    filterfn = hasextension(extensions)
    return DocumentFolder(["$m/doc/" => pkgdir(m) for m in ms]; filterfn, kwargs...)
end

# Utilities

hasextension(f, ext) = endswith(f, string(ext))
hasextension(f, exts::Vector) = any(map(ext -> hasextension(f, ext), exts))
hasextension(exts) = Base.Fix2(hasextension, exts)

@testset "DocumentFolder [rewriter]" begin
    dir = mktempdir()
    touch(joinpath(dir, "test.md"))
    r = DocumentFolder(["pre/" => dir])
    sources = createsources!(r)
    # Should find the file
    @test length(sources) == 1
    # And assign the correct document ID
    @test first(keys(sources)) == "pre/test.md"
    # Since `createsources!` is stateful, the file should only be returned once
    @test isempty(createsources!(r))
    touch(joinpath(dir, "test2.md"))
    # But a new file will be found
    @test "pre/test2.md" in keys(createsources!(r))
    # After resetting, both files will be found
    reset!(r)
    @test length(createsources!(r)) == 2
end
