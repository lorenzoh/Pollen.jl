const DEFAULT_DOCUMENT_EXTENSIONS = ["md", "ipynb"]

struct DocumentFolder <: Rewriter
    dirs::Vector{Pair{String, String}}
    filterfn::Any
    loadfn::Any
    files::Dict{String, FileLoader}
end


"""
    DocumentFolder(dirs; kwargs...) <: Rewriter

A [`Rewriter`](#) that creates new documents from files in the directories `dirs`.

Also handles watching and reloading files in development mode.

See [`DocumentFiles`](#) and [`SourceFiles`](#) as examples of how it is used.

## Keyword arguments

- `filterfn`: Function `filepath -> Bool` that filters which files are loaded
- `loadfn`: Function `filepath -> Node` that loads a file into a [`Node`](#)
"""
function DocumentFolder(
        dirs::Vector;
        extensions = DEFAULT_DOCUMENT_EXTENSIONS,
        filterfn = _ -> true,
        loadfn = _defaultload)

    if !(isnothing(extensions) || isempty(extensions))
        _filterfn = f -> (filterfn(f) && hasextension(f, extensions))
    end
    return DocumentFolder(
        map(d -> d isa Pair ? d : "" => d, dirs),
        _filterfn, loadfn, Dict{String, FileLoader}()
    )
end

_defaultload(file, _) = Pollen.parse(Path(file))


function Base.show(io::IO, df::DocumentFolder)
    print(io, "DocumentFolder(", length(keys(df.files)), " files, ", length(df.dirs),
          " folders)")
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
    DocumentationFiles(modules; extensions, filterfn) <: Rewriter

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
function DocumentationFiles(dirs::Vector{String}, names::Vector{String}; extensions = ["md", "ipynb"])
    return DocumentFolder(
        ["doc/$name/" => dir for (dir, name) in zip(dirs, names)];
        extensions, loadfn = __load_documentation_file)
end

function DocumentationFiles(ms::Vector{Module}; kwargs...)
    pkgdirs = pkgdir.(ms)
    if any(isnothing, pkgdirs)
        i::Int = findfirst(isnothing, pkgdirs)
        throw(ArgumentError("Could not find a package directory for module '$(ms[i])'"))
    end
    DocumentationFiles(pkgdirs, string.(ms); kwargs...)
end
DocumentationFiles(m::Module; kwargs...) = DocumentationFiles([m]; kwargs...)


default_config(::typeof(DocumentationFiles)) = Dict(
    "extensions" => String["md", "ipynb"],
    "index" => default_config(PackageIndex)
)
canonicalize_config(::typeof(DocumentationFiles), config::Dict) = merge(config, Dict(
    "index" => canonicalize_config(PackageIndex, get(config, "index", [])),
))

function default_config_project(::typeof(DocumentationFiles), project_config)
    config = default_config(DocumentationFiles)
    config["index"] = default_config_project(PackageIndex, project_config)
    @show config
    config
end

function from_config(::typeof(DocumentationFiles), config)
    @show config
    config = with_default_config(DocumentationFiles, config)
    index = from_config(PackageIndex, config["index"])
    @show config
    @show index.packages
    DocumentationFiles(
        index.packages.basedir, index.packages.name;
        extensions=config["extensions"])
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

hasextension(file, ext) = endswith(file, string(ext))
hasextension(file, exts::Vector) = any(map(ext -> hasextension(file, ext), exts))
hasextension(exts) = Base.Fix2(hasextension, exts)

function rglob(filepattern = "*", dir = pwd(), depth = 5)
    patterns = ["$(repeat("*/", i))$filepattern" for i in 0:depth]
    return vcat([glob(pattern, dir) for pattern in patterns[1:depth]]...)
end

# ## Tests

@testset "DocumentFolder [rewriter]" begin
    @testset "Basic" begin
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
    @testset "in Pollen" begin
        rewriter = DocumentFolder(["src/" => joinpath(pkgdir(Pollen), "src")], extensions=["jl"])
        docs = Pollen.createsources!(rewriter)
        @test all(startswith(docid, "src/") for docid in keys(docs))
        @test "src/Pollen.jl" in keys(docs)
        @test tag(docs["src/Pollen.jl"]) === :julia
        @test isempty(Pollen.createsources!(rewriter))
        @test_nowarn geteventhandler(rewriter, Channel())
    end

    @testset "DocumentationFiles" begin
        rewriter = DocumentationFiles([Pollen])
        docs = createsources!(rewriter)
        @test "doc/Pollen/README.md" in keys(docs)
    end
    # TODO: test file watcher for individual files as well as directories
end
