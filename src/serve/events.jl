"""
    abstract type Event

An event that can during an interactive serving of a project
using a `Server`. Can be created by a `ServerMode` or a
`Rewriter`.
"""
abstract type Event end


struct DocUpdated <: Event
    name::AbstractPath
    doc::XTree
end

struct DocRequested <: Event
    name::AbstractPath
end


"""
    start(eventsource)

Start an event source.
"""
function start end

start(es::Vector) = foreach(start, es)
"""
    stop(eventsource)

Stop an event source.
"""
function stop end
stop(es::Vector) = foreach(stop, es)


start(watcher::LiveServer.SimpleWatcher) = LiveServer.start(watcher)
stop(watcher::LiveServer.SimpleWatcher) = LiveServer.stop(watcher)


mutable struct FileServer
    dir
    t
    kwargs
    FileServer(dir::AbstractPath; kwargs...) = new(dir, nothing, kwargs)
end

function start(fs::FileServer)
    fs.t = @async begin
        LiveServer.serve(;dir=string(fs.dir), fs.kwargs...)
    end
end

function stop(fs::FileServer)
    if !(isnothing(fs.t) || istaskdone(fs.t) || istaskfailed(fs.t))
        schedule(fs.t, InterruptException(), error=true)
    end
end
