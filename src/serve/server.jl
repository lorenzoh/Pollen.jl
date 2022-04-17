

"""
    Server(project, builder)

A server manages interactively running a `Project`, coordinating events
to update project state efficiently.
"""
mutable struct Server
    project::Any
    builder::Any
    updates::Any
    lock::Any
end

Server(project, builder = FileBuilder(HTMLFormat(), Path(mktempdir()))) =
    Server(project, builder, Updates(), ReentrantLock())

"""
    abstract type ServerMode

Mode that a `Server` can run in. Controls how events affect the project
state.
"""
abstract type ServerMode end

geteventhandler(::ServerMode, server, ch) = nothing

handle(_, ::ServerMode, ::Event) = return

initialize(::ServerMode, server) = return

"""
    handle(server, mode, event)
    handle(rewriter, event)
"""
function handle end


"""
    runserver(server, mode)

Run a `server` in `mode`. Handles start and cleanup of event sources
from rewriters and `mode`. Synchronizes updates to project state.
"""
function runserver(server, mode; dt = 1 / 60)
    eventch = Channel()
    eventhandlers = servereventhandlers(server, mode, eventch)
    initialize(mode, server)
    @async begin
        for event in eventch
            @debug "Received $(typeof(event))"
            try
                handle(server, mode, event)
                foreach(r -> handle(r, event), eventhandlers)
            catch e
                @error "Error was thrown during handling of event!" event = event error = e
            end
        end
    end
    tasks = nothing
    try
        tasks = map(startasync, eventhandlers)
        @info "Starting server..."
        while true
            updates = server.updates
            lock(server.lock) do
                server.updates = Updates()
            end
            _, events = applyupdates!(server.project, server.builder, updates)
            foreach(e -> put!(eventch, e), events)
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
        isnothing(tasks) || foreach(stopasync, eventhandlers, tasks)
        close(eventch)
    end
end


#=
[`Updates`](#) is a container that asynchronously collects updates to
the project state which are then applied synchronously. For example,
a file watcher can update source documents using [`addsource!`](#) and
trigger rewrites and builds using [`addrewrite!`](#) and [`addbuild!`].
Only in [`applyupdates!`](#) are the changes actually applied to a project. =#

"""
    struct Updates

Tracks updates to project state. Used internally by [`runserver`](#).
"""
struct Updates
    sources::Any
    torewrite::Any
    torebuild::Any
end

Updates() = Updates(Dict{String,Node}(), Set{String}(), Set{String}())


"""
    applyupdates!(project, builder, updates::Updates)

Apply `updates` to a project by updating sources, rewriting and building
documents.
"""
function applyupdates!(project, builder, updates::Updates)

    events = Event[]

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
        for p in dirtypaths
            push!(events, DocRebuilt(p))
        end
    end

    return project, events
end

applyupdates!(server::Server) =
    applyupdates!(server.project, server.builder, server.updates)

function addsource!(server, docid, doc)
    lock(server.lock) do
        server.updates.sources[docid] = doc
    end
end

function addrewrite!(server, docid)
    lock(server.lock) do
        if haskey(server.project.sources, docid) || haskey(server.updates.sources, path)
            push!(server.updates.torewrite, docid)
        else
            @warn "Cannot find source document $docid to rewrite!"
            error("Cannot find source document $docid to rewrite!")
        end
    end
end

function addbuild!(server, docid)
    lock(server.lock) do
        if haskey(server.project.outputs, docid) || path in server.updates.torewrite
            push!(server.updates.torebuild, docid)
        else
            error("Cannot find output document $docid to build!")
        end
    end
end


function servereventhandlers(server, mode, ch)
    eventhandlers = []
    for rewriter in server.project.rewriters
        eventhandler = geteventhandler(rewriter, ch)
        isnothing(eventhandler) || push!(eventhandlers, eventhandler)
    end
    eventhandler = geteventhandler(mode, server, ch)
    isnothing(eventhandler) || push!(eventhandlers, eventhandler)

    return eventhandlers
end
