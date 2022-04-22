struct DocumentFolder <: Rewriter
    dir::AbstractPath
    documents::Dict{String, Node}
    dirty::Dict{String, Bool}
    prefix::Any
    extensions
    includehidden
    filterfn
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
DocumentFolder(
    dir::AbstractPath;
    prefix = nothing,
    extensions = ("ipynb", "md"),
    includehidden = false,
    filterfn = (p) -> true,
) = return DocumentFolder(
        absolute(dir),
        Dict{String, Node}(),
        Dict{String, Bool}(),
        prefix,
        extensions,
        includehidden,
        filterfn)

DocumentFolder(p::String, args...; kwargs...) = DocumentFolder(Path(p), args...; kwargs...)


function createsources!(rewriter::DocumentFolder)
    sources = Dict{String, Node}()
    for p in _iterpaths(rewriter)
        docid = _getdocid(rewriter, p)
        isdirty = get(rewriter.dirty, docid, true)
        if isdirty
            # (re)load document
            p_abs = absolute(joinpath(rewriter.dir, p))
            document = _newdocument(p_abs, Pollen.parse(p_abs))
            sources[docid] = rewriter.documents[docid] = document
            rewriter.dirty[docid] = false
        end
    end

    return sources
end

function _newdocument(path, doc)
    xtitle = selectfirst(doc, SelectTag(:h1))
    title = isnothing(xtitle) ? filename(path) : gettext(xtitle)
    attrs = Dict(:path => string(path), :title => title)
    return Node(:document, [doc], attrs)
end

function geteventhandler(folder::DocumentFolder, ch)
    watcher = LiveServer.SimpleWatcher() do filename
        @show filename
        try
            @info "$filename was updated"
            srcpath = Path(filename)
            doc = _newdocument(srcpath, Pollen.parse(srcpath))

            docpath = relative(srcpath, folder.dir)
            if !isnothing(folder.prefix)
                docpath = joinpath(Path(folder.prefix), docpath)
            end
            event = DocUpdated(docpath, doc)
            put!(ch, event)
        catch e
            @error "Error while processing file update for \"$filename\"" e=e
        end
    end
    for docid in keys(folder.documents)
        path = if isnothing(folder.prefix)
            joinpath(folder.dir, docid)
        else
            joinpath(folder.dir, docid[length(folder.prefix)+2:end])
        end
        LiveServer.watch_file!(watcher, string(path))
    end
    return watcher
end


function filehandlers(folder::DocumentFolder, ::Project, ::Builder)
    return Dict(
        () => Dict(relative(p, folder.dir) => Pollen.parse(p)) for p in folder.paths
    )
end




@testset "DocumentFolder [rewriter]" begin
    mktempdir() do dir
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
    end
end

# ## Helpers

# iterates over paths in the document folder, respectig the filter rules
_iterpaths(rewriter::DocumentFolder) = (
    joinpath(relative(absolute(p), rewriter.dir))
        for p in walkpath(rewriter.dir)
            if extension(p) in rewriter.extensions &&
                rewriter.filterfn(p) &&
                (rewriter.includehidden || !_ishidden(relative(absolute(p), rewriter.dir))))

# form a document ID string for a path
_getdocid(rewriter::DocumentFolder, p::AbstractPath) =
    string(isnothing(rewriter.prefix) ? p : joinpath(Path(rewriter.prefix), p))


_ishidden(p::AbstractPath) = any(startswith(s, '.') && s != "." for s in p.segments)
