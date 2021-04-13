

"""
    Server(project, builder)

A server manages interactively running a `Project`, coordinating events
to update project state efficiently.
"""
mutable struct Server
    project
    builder
    updates
    lock
end

Server(project, builder = FileBuilder(HTML(), Path(mktempdir()))) = Server(project, builder, Updates(), ReentrantLock())

"""
    abstract type ServerMode

Mode that a `Server` can run in. Controls how events affect the project
state.
"""
abstract type ServerMode end

geteventsource(::ServerMode, server, ch) = nothing
geteventsource(::Rewriter, ch) = nothing

initialize(::ServerMode, server) = return
"""
    handle(server, mode, event)
"""
function handle end


"""
    runserver(server, mode)

Run a `server` in `mode`. Handles start and cleanup of event sources
from rewriters and `mode`. Synchronizes updates to project state.
"""
function runserver(server, mode; dt=1 / 60)
    eventch = Channel()
    eventsources = servereventsources(server, mode, eventch)
    initialize(mode, server)
    @async begin
        for event in eventch
            @debug "Received $(typeof(event))"
            try
            handle(server, mode, event)
            catch e
                @error "Error was thrown during handling of event!" event=event error=e
            end
        end
    end
    try
        @info "Starting server..."
        start(eventsources)
        while true
            updates = server.updates
            lock(server.lock) do
                server.updates = Updates()
            end
            applyupdates!(server.project, server.builder, updates)
            if !all(isempty.((updates.sources, updates.torewrite, updates.torebuild)))
                @info "Rebuild complete."
            end
            sleep(dt)
        end
    catch e
        if e isa InterruptException
            @info "Shutting down server..."
        else
            rethrow(e)
        end
    finally
        stop(eventsources)
        close(eventch)
    end
end


#=
[`Updates`](#) is a container that asynchronously collects updates to
the project state which are then applied snychronously. For example,
a file watcher can update source documents using [`addsource!`](#) and
trigger rewrites and builds using [`addrewrite!`](#) and [`addbuild!`].
Only in [`applyupdates!`](#) are the changes actually applied to a project. =#

"""
    struct Updates

Tracks updates to project state. Used internally by [`runserver`](#).
"""
struct Updates
    sources
    torewrite
    torebuild
end

Updates() = Updates(Dict{AbstractPath,XTree}(), Set{AbstractPath}(), Set{AbstractPath}())


"""
    applyupdates!(project, builder, updates::Updates)

Apply `updates` to a project by updating sources, rewriting and building
documents.
"""
function applyupdates!(project, builder, updates::Updates)
    for (p, doc) in updates.sources
        project.sources[p] = doc
    end

    dirtypaths = if !isempty(updates.torewrite)
        rewritesources!(project, updates.torewrite)
    else
        Set()
    end
    dirtypaths = union(dirtypaths, updates.torebuild)

    if !isempty(dirtypaths)
        build(builder, project, dirtypaths)
    end

    return project
end

applyupdates!(server::Server) = applyupdates!(server.project, server.builder, server.updates)

function addsource!(server, path, doc)
    lock(server.lock) do
        server.updates.sources[path] = doc
    end
end

function addrewrite!(server, path)
    lock(server.lock) do
        if haskey(server.project.sources, path) || haskey(server.updates.sources, path)
            push!(server.updates.torewrite, path)
        else
            error("Cannot find source document $path to rewrite!")
        end
    end
end

function addbuild!(server, path)
    lock(server.lock) do
        if haskey(server.project.outputs, path) || path in server.updates.torewrite
            push!(server.updates.torebuild, path)
        else
            error("Cannot find output document $path to build!")
        end
    end
end


function servereventsources(server, mode, ch)
    eventsources = []
    for rewriter in server.project.rewriters
        push!(eventsources, geteventsource(rewriter, ch))
    end
    push!(eventsources, geteventsource(mode, server, ch))
    return collect(filter(!isnothing, eventsources))
end
