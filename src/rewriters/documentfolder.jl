struct DocumentFolder <: Rewriter
    dir::AbstractPath
    paths::Vector{<:AbstractPath}
end


function createdocs(folder::DocumentFolder)
    docs = Dict{AbstractPath, XNode}
    Threads.@threads for p in folder.paths
        docs[relative(p, folder.dir)] = parse(p)
    end
    return docs
end


function filehandlers(folder::DocumentFolder, ::Project, ::Builder)
    return Dict(() => Dict(relative(p, folder.dir) => Pollen.parse(p)) for p in folder.paths)
end
