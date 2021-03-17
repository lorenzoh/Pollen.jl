"""
    servelazy(project, dir)



"""
function servelazy(project::Project, dir; dstdir = Path(mktempdir()))
    reset!(project)

    # Do an empty build once for assets etc.
    builder = FileBuilder(HTML(), dstdir)
    build(project, builder)

    server = LazyServer(project, dir, builder, getwatcher(project, dir, builder))
    HTTP.serve(server, verbose = true)
end


mutable struct LazyServer
    project::Project
    dir::AbstractPath
    builder::FileBuilder
    watcher::LiveServer.SimpleWatcher
end

function (server::LazyServer)(req::HTTP.Request)
    p = Path(req.target[2:end])
    return server(p)
end

function (server::LazyServer)(path::AbstractPath)
    # Check if document is already built
    if path == p"."
        return server(p"index.html")
    end
    buildpath = joinpath(server.builder.dir, path)
    if isfile(buildpath)
        return String(read(buildpath))
    end

    # Check if document is not built but is physical file
    if extension(path) == "html"
        srcpath = joinpath(server.dir, parent(path), filename(path))
        if isfile(srcpath)
            @info "Building $srcpath for the first time..."
            # Add it to sources and rebuild the project
            dirtypaths = addfiles!(server.project, Dict(path => Pollen.parse(srcpath)))
            LiveServer.stop(server.watcher)
            server.watcher = getwatcher(server.project, server.dir, server.builder)
            build(server.builder, server.project, dirtypaths)
            @assert isfile(buildpath)
            return String(read(buildpath))
        end
    end

    @info "Failed to request $path"
    return "404"
end
