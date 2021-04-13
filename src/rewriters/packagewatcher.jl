
"""
    PackageWatcher(modules) <: Rewriter


Rebuild when a source file in one of `modules` changes.

"""
struct PackageWatcher <: Rewriter
    modules
    handler
end

# FIXME: remove old constructor and handler field
PackageWatcher(modules) = PackageWatcher(modules, 1)

# TODO: update to work with event-based serving


function geteventsource(pkgwatcher::PackageWatcher, ch)
    watcher = LiveServer.SimpleWatcher(filename -> onsourcefilechanged(Path(filename), ch))
    for m in pkgwatcher.modules
        srcdir = joinpath(Path(pkgdir(m)), "src")
        for p in walkpath(srcdir)
            LiveServer.watch_file!(watcher, string(p))
        end
    end
    return watcher
end


struct SourceFileUpdated <: Event
    p::AbstractPath
end


function onsourcefilechanged(p, ch)
    @info "Source code file $p changed, revising and rebuilding..."
    Revise.revise()
    event = SourceFileUpdated(p)
    put!(ch, event)
end


function handle(server, ::ServerMode, ::SourceFileUpdated)
    # clear executecode cache
    for rewriter in server.project.rewriters
        if rewriter isa ExecuteCode
            reset!(rewriter)
        elseif rewriter isa Referencer
            reset!(rewriter)
        end
    end
    for p in keys(server.project.sources)
        # only REbuild
        if p in keys(server.project.outputs)
            addrewrite!(server, p)
            addbuild!(server, p)
        end
    end
end
