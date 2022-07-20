struct DocumentFolder <: Rewriter
    dir::AbstractPath
    documents::Dict{String, Node}
    dirty::Dict{String, Bool}
    prefix::Any
    extensions::Any
    includehidden::Any
    filterfn::Any
end

function Base.show(io::IO, rewriter::DocumentFolder)
    print(io, "DocumentFolder(\"", rewriter.dir, "\"")
    if !isnothing(rewriter.prefix)
        print(", prefix = \"", rewriter.prefix, "\"")
    end
    print(")")
end

"""
    DocumentFolder(dir) <: Rewriter

Rewriter to add source documents from a folder to a project.

For every file `\$dir/\$subpath`, a new source document with id `\$subpath`
is added to a project.

## Keyword arguments

- `prefix = nothing`: Prefix for document ids. If a string is given document ids
    will have the form `\$prefix\$subpath`
- `extensions = ("ipynb", "md")`: List of file extensions that should be loaded.
- `includehidden = false`: Whether to load documents from hidden files and directories.
- `filterfn = p -> true`: Filter applied to every path. Return `false` for a path to not
    load it.
"""
function DocumentFolder(dir::AbstractPath;
                        prefix = nothing,
                        extensions = ("ipynb", "md"),
                        includehidden = false,
                        filterfn = (p) -> true)
    return DocumentFolder(absolute(dir),
                          Dict{String, Node}(),
                          Dict{String, Bool}(),
                          prefix,
                          extensions,
                          includehidden,
                          filterfn)
end

DocumentFolder(p::String, args...; kwargs...) = DocumentFolder(Path(p), args...; kwargs...)

function createsources!(rewriter::DocumentFolder)
    sources = Dict{String, Node}()
    for p in _iterpaths(rewriter)
        docid = _getdocid(rewriter, p)
        isdirty = get(rewriter.dirty, docid, true)
        if isdirty
            # (re)load document
            p_abs = absolute(joinpath(rewriter.dir, p))
            document = __loadfile(p_abs)
            sources[docid] = rewriter.documents[docid] = document
            rewriter.dirty[docid] = false
        end
    end

    return sources
end

function __loadfile(filepath)
    doc = Pollen.parse(Path(filepath))
    xtitle = selectfirst(doc, SelectTag(:h1))
    title = isnothing(xtitle) ? filename(Path(filepath)) : gettext(xtitle)
    attrs = Dict(:path => string(filepath), :title => title)
    return Node(:document, [doc], attrs)
end

#= Turn this into

geteventhandler(_, _) = getfilewatcher(folder.documentfiles)

=#
function geteventhandler(folder::DocumentFolder, ch)
    documents = Dict{String, String}(string(_getpath(folder, docid)) => docid
                                     for docid in keys(folder.documents))
    return createfilewatcher(documents, ch) do file
        __loadfile(file)
    end
end

function _getpath(folder::DocumentFolder, docid)
    if isnothing(folder.prefix)
        joinpath(folder.dir, docid)
    else
        joinpath(folder.dir, docid[(length(folder.prefix) + 2):end])
    end
end

"""
    createfilewatcher(documents, channel)

Create a file watcher that can be used as an event source when serving.
`documents` is a `Dict` with entries `filepath => docid`.
"""
function createfilewatcher(loadfn, documents::Dict{String, String}, ch::Channel)
    watcher = LiveServer.SimpleWatcher() do filepath
        try
            @info "Source file $filepath was updated"
            doc = loadfn(filepath)
            docid = documents[filepath]
            event = DocUpdated(docid, doc)
            put!(ch, event)
        catch e
            @error "Error while processing file update for \"$filepath\" (document ID \"$(documents[filepath])\"" e=e
        end
    end
    for (filepath, docid) in documents
        LiveServer.watch_file!(watcher, filepath)
    end
    return watcher
end

function filehandlers(folder::DocumentFolder, ::Project, ::Builder)
    return Dict(() => Dict(relative(p, folder.dir) => Pollen.parse(p))
                for p in folder.paths)
end

@testset "DocumentFolder [rewriter]" begin mktempdir() do dir
    open(joinpath(dir, "test.md"), "w") do f
        write(f, "# Test")
    end
    rewriter = DocumentFolder(Path(dir))
    sources = createsources!(rewriter)
    @test haskey(sources, "test.md")
    doc = sources["test.md"]
    @test tag(doc) == :document
    @test haskey(attributes(doc), :path)
    @test children(doc)[1] == Node(:md, Node(:h1, "Test"))
end end

# ## Helpers

# iterates over paths in the document folder, respectig the filter rules
function _iterpaths(rewriter::DocumentFolder)
    (joinpath(relative(absolute(p), rewriter.dir))
     for p in walkpath(rewriter.dir)
     if extension(p) in rewriter.extensions &&
        rewriter.filterfn(p) &&
        (rewriter.includehidden || !_ishidden(relative(absolute(p), rewriter.dir))))
end

# form a document ID string for a path
function _getdocid(rewriter::DocumentFolder, p::AbstractPath)
    string(isnothing(rewriter.prefix) ? p : joinpath(Path(rewriter.prefix), p))
end

_ishidden(p::AbstractPath) = any(startswith(s, '.') && s != "." for s in p.segments)
