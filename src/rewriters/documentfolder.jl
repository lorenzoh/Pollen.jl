"""
    DocumentFolder(dirs; kwargs...) <: Rewriter

A [`Rewriter`](#) that creates new documents from files in the directories `dirs`.

Also handles watching and reloading files in development mode.

See [`DocumentFiles`](#) and [`SourceFiles`](#) as examples of how it is used.

## Keyword arguments

- `filterfn`: Function `filepath -> Bool` that filters which files are loaded
- `loadfn`: Function `filepath -> Node` that loads a file into a [`Node`](#)
"""
Base.@kwdef struct DocumentFolder <: Rewriter
    dirs::Vector{Pair{String, String}}
    filterfn = hasextension(["md", "ipynb"])
    loadfn = _defaultload
    files::Dict{String, FileLoader} = Dict{String, FileLoader}()
end
_defaultload(file, _) = Pollen.parse(Path(file))

function Base.show(io::IO, df::DocumentFolder)
    print(io, "DocumentFolder(", length(keys(df.files)), " files, ", length(df.dirs),
          " folders)")
end

function DocumentFolder(dirs::Vector; kwargs...)
    DocumentFolder(; dirs = map(d -> d isa Pair ? d : "" => d, dirs), kwargs...)
end
DocumentFolder(dir::String; kwargs...) = DocumentFolder([dir]; kwargs...)

function createsources!(rewriter::DocumentFolder)
    sources = Dict{String, Node}()
    for (prefix, dir) in rewriter.dirs
        for file::String in filter(rewriter.filterfn, rglob("*", dir))
            docid = "$(prefix)$(relpath(file, dir))"

            # Skip if already created
            docid in keys(rewriter.files) && continue
            rewriter.files[docid] = FileLoader(file, docid,
                                               () -> rewriter.loadfn(file, docid))
            sources[docid] = rewriter.loadfn(file, docid)
        end
    end
    return sources
end

function reset!(rewriter::DocumentFolder)
    # Clear the dictionary with collected files, so they can be recreated
    empty!(rewriter.files)
end

function geteventhandler(rewriter::DocumentFolder, ch)
    return makefilewatcher(ch, collect(values(rewriter.files)), last.(rewriter.dirs))
end

"""
    DocumentationFiles(modules; kwargs) <: Rewriter

A [`Rewriter`](#) that finds written documentation like `.md` files in the package
directories of `modules` and adds them to a [`Project`]'s.

It finds all files in the directories `dir = pkgdir(m ∈ modules)`. Then, if the file's
extension matches one of `extensions`, a document with ID
`"(pkgname)"@(pkgversion)/(filepath)` is created.

Also handles watching and reloading files in development mode.

## Keyword arguments

- `extensions = ["md", "ipynb"]`: File extensions to include
- `pkgtags = Dict()`: Overwrite package versions

"""
function DocumentationFiles(ms::Vector{Module}; extensions = ["md", "ipynb"],
                            pkgtags = Dict{String, String}(), kwargs...)
    filterfn = hasextension(extensions)
    pkgdirs = pkgdir.(ms)
    pkgids = __getpkgids(ms; pkgtags)
    if any(isnothing, pkgdirs)
        i::Int = findfirst(isnothing, pkgdirs)
        throw(ArgumentError("Could not find a package directory for module '$(ms[i])'"))
    end
    return DocumentFolder(["$pkgid/doc/" => dir for (pkgid, dir) in zip(pkgids, pkgdirs)];
                          filterfn, loadfn = __load_documentation_file, kwargs...)
end
DocumentationFiles(m::Module; kwargs...) = DocumentationFiles([m]; kwargs...)


default_config(::typeof(DocumentationFiles)) = Dict(
    "packages" => String[],
    "extensions" => String["md", "ipynb"],
    "tags" => Dict(),
)

function from_config(::typeof(DocumentationFiles), config)
    merge_configs(default_config(DocumentationFiles), config)
    modules = map(load_package, config["packages"])
    DocumentationFiles(modules, extensions=config["extensions"], pkgtags=tags)
end


function __load_documentation_file(file, id)
    pfile = Path(file)
    doc = Pollen.parse(pfile)
    node_title = selectfirst(doc, SelectTag(:h1))
    title = isnothing(node_title) ? filename(pfile) : gettext(node_title)
    attrs = Dict(:path => string(file), :title => title)
    return Node(:document, children(doc), merge(attrs, attributes(doc)))
end

# Utilities

function __getpkgids(ms; pkgtags = Dict{String, String}())
    return ["$m@$(get(pkgtags, string(m), ModuleInfo.packageversion(m)))"
            for m in ms]
end

hasextension(f, ext) = endswith(f, string(ext))
hasextension(f, exts::Vector) = any(map(ext -> hasextension(f, ext), exts))
hasextension(exts) = Base.Fix2(hasextension, exts)

function rglob(filepattern = "*", dir = pwd(), depth = 5)
    patterns = ["$(repeat("*/", i))$filepattern" for i in 0:depth]
    return vcat([glob(pattern, dir) for pattern in patterns[1:depth]]...)
end

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
