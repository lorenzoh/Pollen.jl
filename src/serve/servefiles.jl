
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
                      preprocess_request = req -> _lazyservecallback(req, ch, builddir, server.project))
end

function _lazyservecallback(req, ch, builddir, project)
    # TODO FIXME this will break for extensions without exactly 4 characters
    documentid = req.target[2:(end - 5)]
    if !(endswith(req.target, ".html") || endswith(req.target, ".json")) || !(documentid in keys(project.sources))
        LiveServer.HTTP.setheader(req, "Access-Control-Allow-Origin" => "*")
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
        sourcepath = Path(documentid)  # cut off / and .html
        put!(ch, DocRequested(sourcepath))
        # Give time to build so file server doesn't instantly return a 404
        sleep(0.05)
        return req
    end
end
