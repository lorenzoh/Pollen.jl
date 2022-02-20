struct DocumentFolder <: Rewriter
    dir::AbstractPath
    paths::Vector{<:AbstractPath}
    dirty::BitVector
    prefix::Any
end


function DocumentFolder(
    dir::AbstractPath;
    prefix = nothing,
    extensions = ("ipynb", "md"),
    includehidden = false,
    filterfn = (p) -> true,
)

    dir = absolute(dir)
    paths = AbstractPath[
        joinpath(relative(absolute(p), dir)) for
        p in walkpath(dir) if extension(p) in extensions &&
        filterfn(p) &&
        (includehidden || !ishidden(relative(absolute(p), dir)))
    ]
    return DocumentFolder(dir, paths, trues(length(paths)), prefix)
end
DocumentFolder(p::String, args...; kwargs...) = DocumentFolder(Path(p), args...; kwargs...)


function createsources!(folder::DocumentFolder)
    docs = Dict{AbstractPath,XNode}()
    for (i, p) in enumerate(folder.paths)
        if folder.dirty[i]
            srcpath = joinpath(folder.dir, p)
            docpath = isnothing(folder.prefix) ? p : joinpath(Path(folder.prefix), p)
            rawdoc = Pollen.parse(srcpath)
            docs[docpath] = _newdocument(srcpath, rawdoc)

            folder.dirty[i] = false
        end
    end
    return docs
end

function _newdocument(path, doc)
    xtitle = selectfirst(doc, SelectTag(:h1))
    title = isnothing(xtitle) ? filename(path) : gettext(xtitle)
    attrs = Dict(:path => string(path), :title => title)
    return XNode(:document, merge(attributes(doc), attrs), children(doc))
end

function geteventhandler(folder::DocumentFolder, ch)
    watcher = LiveServer.SimpleWatcher() do filename
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
    for p in folder.paths
        LiveServer.watch_file!(watcher, string(joinpath(folder.dir, p)))
    end
    return watcher
end


function filehandlers(folder::DocumentFolder, ::Project, ::Builder)
    return Dict(
        () => Dict(relative(p, folder.dir) => Pollen.parse(p)) for p in folder.paths
    )
end


ishidden(p::AbstractPath) = any(startswith(s, '.') && s != "." for s in p.segments)
