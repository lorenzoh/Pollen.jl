
"""
    PackageWatcher(modules) <: Rewriter


Rebuild when a source file in one of `modules` changes.

"""
struct PackageWatcher <: Rewriter
    modules
    handler
end

PackageWatcher(modules) = PackageWatcher(modules, handlepkgupdate)


function getfilehandlers(watcher::PackageWatcher, project, dir, builder)
    handlers = []
    for m in watcher.modules
        srcdir = joinpath(Path(pkgdir(m)), "src")
        for p in walkpath(srcdir)
            push!(handlers, (p, () -> watcher.handler(m, p, builder, project)))
        end
    end
    return handlers
end


function handlepkgupdate(m::Module, p::AbstractPath, builder, project)
    @info "Code in $m changed ($p), revising and rebuilding..."
    Revise.revise()
    rebuild(builder, project)
end
