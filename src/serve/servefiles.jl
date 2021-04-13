
struct ServeFiles <: ServerMode end


function handle(server, ::ServeFiles, event::DocUpdated)
    addsource!(server, event.name, event.doc)
    addrewrite!(server, event.name)
    addbuild!(server, event.name)
end

function geteventsource(::ServeFiles, server, ch)
    return FileServer(server.builder.dir)
end

function initialize(::ServeFiles, server)
    @info "Starting initial build..."
    fullbuild(server.project, server.builder)
    @info "Done."
end

struct ServeFilesLazy <: ServerMode end


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
    if (event.name ∈ keys(server.project.sources)) && !(event.name ∈ keys(server.project.outputs))
        @info "Building $(event.name) for the first time..."
        addrewrite!(server, event.name)
        addbuild!(server, event.name)
    end
end


function geteventsource(::ServeFilesLazy, server, ch)
    builddir = server.builder.dir
    return FileServer(builddir, callback = req -> _lazyservecallback(req, ch, builddir))
end


function _lazyservecallback(req, ch, builddir)
    if !endswith(req.target, ".html")
        return
    else
        buildpath = joinpath(builddir, req.target[2:end])
        try mkpath(parent(buildpath)) catch end
        touch(buildpath)
        #=
        open(joinpath(builddir, req.target[2:end]), "w") do f
            write(f, "Building...")
        end
        =#
        sourcepath = Path(req.target[2:end-5])  # cut off / and .html
        put!(ch, DocRequested(sourcepath))
        # Give time to build so file server doesn't instantly return a 404
        sleep(0.05)
    end
end
