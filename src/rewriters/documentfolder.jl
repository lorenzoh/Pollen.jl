struct DocumentFolder <: Rewriter
    dir::AbstractPath
    paths::Vector{<:AbstractPath}
    dirty::BitVector
end


function DocumentFolder(
        dir::AbstractPath;
        prefix = "",
        extensions = ("ipynb", "md"),
        includehidden = false,
        filterfn = (p) -> true)

    dir = absolute(dir)
    paths = AbstractPath[
        joinpath(relative(absolute(p), dir)) for p in walkpath(dir)
            if extension(p) in extensions && filterfn(p) && (includehidden || !ishidden(relative(absolute(p), dir)))]
    return DocumentFolder(dir, paths, trues(length(paths)))
end

function createsources!(folder::DocumentFolder)
    docs = Dict{AbstractPath, XNode}()
     for (i, p) in enumerate(folder.paths)
        if folder.dirty[i]
            docs[p] = parse(joinpath(folder.dir, p))
            folder.dirty[i] = false
        end
    end
    return docs
end


function geteventsource(folder::DocumentFolder, ch)
    watcher = LiveServer.SimpleWatcher() do filename
        @info "$filename was udpated"
        p = Path(filename)
        doc = parse(p)
        event = DocUpdated(relative(p, folder.dir), doc)
        put!(ch, event)
    end
    for p in folder.paths
        LiveServer.watch_file!(watcher, string(joinpath(folder.dir, p)))
    end
    return watcher
end


function filehandlers(folder::DocumentFolder, ::Project, ::Builder)
    return Dict(() => Dict(relative(p, folder.dir) => Pollen.parse(p)) for p in folder.paths)
end


ishidden(p::AbstractPath) = any(startswith(s, '.') && s != "." for s in p.segments)
