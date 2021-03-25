

function findfiles(dir::AbstractPath; exts = ("md", "ipynb"), includehidden = false)
    it = filter(collect((relative(p, dir) for p in walkpath(dir)))) do p
        (extension(p) in exts) && (includehidden || !startswith(filename(p), '.'))
    end
    return it

end


mutable struct Project
    sources::Dict{AbstractPath, XTree}
    outputs::Dict{AbstractPath, XTree}
    rewriters::Vector{<:Rewriter}
end

Project(dir::AbstractPath, rewriters::Vector{<:Rewriter}) =
    Project(dir, collect(findfiles(dir)), rewriters)

Project(paths::Vector{<:AbstractPath}, rewriters::Vector{<:Rewriter}) =
    Project(Path(pwd()), paths, rewriters)


function Project(dir::AbstractPath, paths::Vector{<:AbstractPath}, rewriters::Vector{<:Rewriter})
    sources = Dict{AbstractPath, XTree}()
    Threads.@threads for p in paths
        sources[p] = parse(joinpath(dir, p))
    end
    return Project(sources, rewriters)
end


function Project(sources::Dict{AbstractPath, XTree}, rewriters::Vector{<:Rewriter})
    targets = Dict{AbstractPath, XTree}()
    return Project(sources, targets, rewriters)
end


Base.show(io::IO, project::Project) = print(io, "Project($(length(project.sources)) documents, $(typeof.(project.rewriters))")


function addfiles(
        sources::Dict,
        outputs::Dict,
        rewriters,
        newsources;
        dirtypaths = Set())
    sources = copy(sources)
    outputs = copy(outputs)
    dirtypaths = addfiles!(sources, outputs, rewriters, newsources; dirtypaths = dirtypaths)
    return sources, outputs, dirtypaths
end


"""
    addfiles(sources, outputs, rewriters, newsources) -> (sources', outputs', dirtypaths)
    addfiles!(sources, outputs, rewriters, newsources) -> dirtypaths

Updates `sources` and `outputs` based on new or updated `changedsources`
using `rewriters`.
"""
function addfiles!(
        sources::Dict,
        outputs::Dict,
        rewriters,
        newsources::Dict;
        dirtypaths = Set())

    isempty(newsources) && return dirtypaths

    # Process new/changed files on document-level
    for (p, xtree) in newsources
        sources[p] = xtree
        for rewriter in rewriters
            xtree = updatefile(rewriter, p, xtree)
        end
        outputs[p] = xtree
        push!(dirtypaths, p)
    end

    # Apply project-level changes like updating tree elements,
    # and creating new files.
    newersources = Dict{AbstractPath, XNode}()
    for rewriter in rewriters
        new = createdocs(rewriter)
        newersources = merge(newersources, new)
    end

    # Run recursively with new documents
    return addfiles!(sources, outputs, rewriters, newersources; dirtypaths = dirtypaths)
end


function addfiles!(project::Project, newsources)
    dirtypaths = addfiles!(project.sources, project.outputs, project.rewriters, newsources)
    return dirtypaths
end


function reset!(project::Project)
    foreach(k -> delete!(project.sources, k), keys(project.sources))
    foreach(k -> delete!(project.outputs, k), keys(project.outputs))
    foreach(reset!, project.rewriters)
end
