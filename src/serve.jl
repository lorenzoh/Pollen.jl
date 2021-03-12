

function serve(project, dst = Path(mktempdir()); format = HTML())
    Pollen.build(project, dst, format)
    handlers = getfilehandlers(project, dst, format)
    watcher = watchfiles(handlers)
    try
        LiveServer.serve(dir=string(dst))
    catch e
        rethrow(e)
    finally
        LiveServer.stop(watcher)
    end

end


function watchfiles(handlers)
    watcher = SimpleWatcher() do file
        p = Path(file)
        handlerfns = get(handlers, p, ())
        for f in handlerfns
            f()
        end
    end
    for p in keys(handlers)
        watch_file!(watcher, string(absolute(p)))
    end
    start(watcher)
    return watcher
end


function getfilehandlers(project::Project, dst, format)
    handlers = Dict{AbstractPath, Any}()
    for f in files(project.srctree)
        p = absolute(path(f))
        if isfile(p)
            append!(handlers, p, () -> defaulthandler(project, p, dst, format))
        end
    end
    for rewriter in project.rewriters
        for (p, handlerfn) in getfilehandlers(rewriter, project, dst, format)
            append!(handlers, p, handlerfn)
        end
    end
    return handlers
end

getfilehandlers(rewriter::Rewriter, project, dst, format) = ()


function defaulthandler(project, p, dst, format)
    println("Rebuilding $p")
    doc = Pollen.parse(p)
    p = relative(p, path(project.srctree))
    dirtypaths = addfiles!(project, [(p, doc)])
    rebuild(project, dst, format, dirtypaths)
end

# Utils

function append!(d::Dict, key, val)
    if !haskey(d, key)
        d[key] = []
    end
    push!(d[key], val)
end
