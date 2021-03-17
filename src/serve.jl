

function serve(project, srcdir::AbstractPath, dstdir = Path(mktempdir()); format = HTML())
    foreach(reset!, project.rewriters)
    srcdir = absolute(srcdir)
    builder = FileBuilder(format, dstdir)
    Pollen.build(project, builder)
    handlers = getfilehandlers(project, srcdir, builder)
    watcher = watchfiles(handlers)
    try
        LiveServer.serve(dir=string(dstdir))
    catch e
        rethrow(e)
    finally
        LiveServer.stop(watcher)
    end

end


function getwatcher(project, dir, builder)
    handlers = getfilehandlers(project, dir, builder)
    return watchfiles(handlers)
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


function getfilehandlers(project::Project, dir, builder)
    handlers = Dict{AbstractPath, Any}()

    # For physical files, rebuild them when they change on disk
    for path in keys(project.sources)
        fullpath = joinpath(dir, path)
        if isfile(fullpath)
            append!(handlers, fullpath, () -> defaulthandler(project, dir, path, builder))
        end
    end

    # Register custom rewriter handlers
    for rewriter in project.rewriters
        for (p, handlerfn) in getfilehandlers(rewriter, project, dir, builder)
            append!(handlers, p, handlerfn)
        end
    end
    return handlers
end

getfilehandlers(::Rewriter, project, dir, builder) = ()


"""

Default file update handler that watches "dir/path", updating `project.sources[path]`
when it changes and triggering a rebuild with `builder`.
"""
function defaulthandler(project, dir, path, builder)
    fullpath = joinpath(dir, path)
    println("Rebuilding $fullpath")
    doc = Pollen.parse(fullpath)
    dirtypaths = addfiles!(project, [(path, doc)])
    build(builder, project, dirtypaths)
end

# Utils

function append!(d::Dict, key, val)
    xs = get!(d, key, [])
    push!(xs, val)
    d[key] = xs
end
