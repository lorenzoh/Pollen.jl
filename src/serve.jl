

function serve(project, dstdir = Path(mktempdir()); format = HTML())
    foreach(reset!, project.rewriters)
    builder = FileBuilder(format, dstdir)
    Pollen.build(project, builder)


    docupdates = Dict{AbstractPath, XNode}
    updatelock = ReentrantLock()
    running = Ref(true)
    # Loop that processes updated/created documents in batches
    @async begin
        while running[]
            lock(updatelock) do
                docs = copy(docupdates)
                foreach(k -> delete!(docupdates, k), keys(docupdates))
            end
            build(project, builder, docs)

            sleep(1/60)
        end
    end



    handlers = filehandlers(project, builder)
    updatech = Channel()
    watcher = watchfiles(handlers, updatech)
    try
        LiveServer.serve(dir=string(dstdir))
    catch e
        rethrow(e)
    finally
        LiveServer.stop(watcher)
        running[] = false
    end

end


function getwatcher(project, dir, builder)
    handlers = getfilehandlers(project, dir, builder)
    return watchfiles(handlers)
end


function watchfiles(handlers, ch)
    watcher = LiveServer.SimpleWatcher() do file
        p = Path(file)
        handlerfns = get(handlers, p, ())
        for f in handlerfns
            f()
        end
    end
    for p in keys(handlers)
        LiveServer.watch_file!(watcher, string(absolute(p)))
    end
    LiveServer.start(watcher)
    return watcher
end


function filehandlers(project::Project, builder::Builder)
    handlers = Dict{AbstractPath, Any}()
    for rewriter in project.rewriters
        for (p, handlerfn) in filehandlers(rewriter, project, builder)
            phandlers = get!(handlers, p, [])
            push!(phandlers, handlerfn)
        end
    end
    return handlers
end

filehandlers(::Rewriter, project, builder) = Dict()
