
struct FileLoader
    path::String
    id::String
    load::Any
end

function makefilewatcher(ch::Channel, loaders::Vector{FileLoader},
                         dirs::Vector{String} = []; filterfn = Returns(true))
    # TODO: watch `dirs` for any added files
    pathtoloader = Dict{String, FileLoader}(loader.path => loader for loader in loaders)
    watcher = LiveServer.SimpleWatcher() do path
        try
            @info "Source file $path was updated"
            loader = pathtoloader[path]
            put!(ch, DocUpdated(loader.id, loader.load()))
        catch e
            loader = pathtoloader[path]
            @error "Error while processing file update for \"$path\" (document ID \"$(loader.id)\"" e=e
        end
    end
    for loader in loaders
        LiveServer.watch_file!(watcher, loader.path)
    end
    return watcher
end
