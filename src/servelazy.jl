"""
    servelazy(project, dir)

Serve `project` lazily, meaning documents will only be built when they're
requested.
"""
function servelazy(
        project::Project,
        dir;
        dstdir = Path(mktempdir()),
        builder = FileBuilder(HTML(), dstdir))

    foreach(reset!, project.rewriters)
    foreach(k -> delete!(project.outputs, k), keys(project.outputs))

    # Do an empty build once for assets etc.
    build(project, builder, Dict())

    server = LazyServer(project, dir, builder, getwatcher(project, dir, builder))
    try
        LiveServer.serve(callback = server, dir = string(dstdir))
    catch e
        rethrow(e)
    finally
    end
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
    # Check if document is not built but is physical file
    buildpath = joinpath(server.builder.dir, path)
    if isfile(buildpath)
        return
    elseif extension(path) == "html"
        docpath = joinpath(parent(path), filename(path))
        srcpath = joinpath(server.dir, docpath)
        if isfile(srcpath)
            @info "Building $docpath for the first time..."
            # Add it to sources and rebuild the project
            dirtypaths = addfiles!(server.project, Dict(docpath => Pollen.parse(srcpath)))
            LiveServer.stop(server.watcher)
            server.watcher = getwatcher(server.project, server.dir, server.builder)
            build(server.builder, server.project, dirtypaths)
            @assert isfile(buildpath)
            return String(read(buildpath))
        end
    end
end
