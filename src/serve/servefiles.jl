
Base.@kwdef struct ServeFiles <: ServerMode
    port::Int = 8000
end

function handle(server, ::ServeFiles, event::DocUpdated)
    addsource!(server, event.name, event.doc)
    addrewrite!(server, event.name)
    addbuild!(server, event.name)
end

function geteventhandler(serve::ServeFiles, server, ch)
    return FileServer(server.builder.dir,
                      port = serve.port,
                      allow_cors = true)
end

function initialize(::ServeFiles, server)
    @info "Starting initial build..."
    fullbuild(server.project, server.builder)
    @info "Done."
end

Base.@kwdef struct ServeFilesLazy <: ServerMode
    port::Int = 8000
end

function initialize(::ServeFilesLazy, server)
    build(server.builder, server.project)
end

function handle(server, ::ServeFilesLazy, event::DocUpdated)
    addsource!(server, event.name, event.doc)
    if event.name in keys(server.project.outputs)
        addrewrite!(server, event.name)
        addbuild!(server, event.name)
    end
end

function handle(server, ::ServeFilesLazy, event::DocRequested)
    if (event.name ∈ keys(server.project.sources)) &&
       !(event.name ∈ keys(server.project.outputs))
        @info "Building $(event.name) for the first time..."
        addrewrite!(server, event.name)
        addbuild!(server, event.name)
    end
end

function geteventhandler(serve::ServeFilesLazy, server, ch)
    builddir = server.builder.dir
    return FileServer(builddir,
                      port = serve.port,
                      allow_cors = true,
                      preprocess_request = req -> _lazyservecallback(req, ch, builddir))
end

function _lazyservecallback(req, ch, builddir)
    if !(endswith(req.target, ".html") || endswith(req.target, ".json"))
        return req
    else
        buildpath = joinpath(builddir, req.target[2:end])
        try
            mkpath(parent(buildpath))
        catch
        end
        touch(buildpath)
        #=
        open(joinpath(builddir, req.target[2:end]), "w") do f
            write(f, "Building...")
        end
        =#
        sourcepath = Path(req.target[2:(end - 5)])  # cut off / and .html
        put!(ch, DocRequested(sourcepath))
        # Give time to build so file server doesn't instantly return a 404
        sleep(0.05)
        return req
    end
end
