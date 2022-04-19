"""
    abstract type Event

An event that can during an interactive serving of a project
using a `Server`. Can be created by a `ServerMode` or a
`Rewriter`.
"""
abstract type Event end


struct DocUpdated <: Event
    name::String
    doc::Node
end

struct DocRequested <: Event
    name::String
end

struct DocRebuilt <: Event
    name::String
end


"""
    geteventhandler
"""
geteventhandler(rewriter::Rewriter, ch) = return rewriter
geteventhandler(_, _) = return

handle(_, event::Event) = nothing


"""
    start(eventhandler)

Start an event source. Use `startasync` to do this asynchronously.
"""
function start end

start(_) = return
stop(_) = return


function startasync(eventhandler)
    task = @async begin
        try
            start(eventhandler)
        catch e
            @error "Error while starting event handler!" error=e handler=eventhandler
        end
    end
    return task
end

function stopasync(eventhandler, task)
    @async begin
        try
            stop(eventhandler)
            if !(istaskdone(task) || istaskfailed(task))
                schedule(task, InterruptException(), error=true)
            end
        catch e
            @error "Error while stopping event handler!" error=e handler=eventhandler
        end
    end
end

stop(watcher::LiveServer.SimpleWatcher) = LiveServer.stop(watcher)

start(watcher::LiveServer.SimpleWatcher) = LiveServer.start(watcher)

mutable struct FileServer
    dir
    kwargs
    FileServer(dir; kwargs...) = new(dir, kwargs)
end

function start(fs::FileServer)
    LiveServer.serve(;dir=string(fs.dir), fs.kwargs...)
end

# TODO: maybe `geteventhandler` not needed and `start(rewriter, channel)` suffices?

"""
    serve(project)
"""
function serve(project::Project, path = mktempdir(); lazy = true, format = JSONFormat(), port = 8000)
    builder = FileBuilder(format, Path(path))
    server = Server(project, builder)
    mode = lazy ? ServeFilesLazy(port) : ServeFiles(port)
    runserver(server, mode)
end
