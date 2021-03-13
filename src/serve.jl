

function serve(project, srcdir::AbstractPath, dst = Path(mktempdir()); format = HTML())
    srcdir = absolute(srcdir)
    Pollen.build(project, dst, format)
    handlers = getfilehandlers(project, srcdir, dst, format)
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


function getfilehandlers(project::Project, srcdir, dst, format)
    handlers = Dict{AbstractPath, Any}()

    # For physical files, rebuild them when they change on disk
    for path in keys(project.sources)
        fullpath = joinpath(srcdir, path)
        if isfile(fullpath)
            append!(handlers, fullpath, () -> defaulthandler(project, path, fullpath, dst, format))
        end
    end

    # Register custom rewriter handlers
    for rewriter in project.rewriters
        for (p, handlerfn) in getfilehandlers(rewriter, project, srcdir, dst, format)
            append!(handlers, p, handlerfn)
        end
    end
    return handlers
end

getfilehandlers(::Rewriter, project, srcdir, dst, format) = ()


function defaulthandler(project, path, fullpath, dst, format)
    println("Rebuilding $path")
    doc = Pollen.parse(fullpath)
    dirtypaths = addfiles!(project, [(path, doc)])
    rebuild(project, dst, format, dirtypaths)
end

# Utils

function append!(d::Dict, key, val)
    xs = get!(d, key, [])
    push!(xs, val)
    d[key] = xs
end
