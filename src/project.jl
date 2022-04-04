

#= TODO: remove
function findfiles(dir::AbstractPath; exts = ("md", "ipynb"), includehidden = false)
    it = filter(collect((relative(p, dir) for p in walkpath(dir)))) do p
        (extension(p) in exts) && (includehidden || !startswith(filename(p), '.'))
    end
    return it
end
=#


mutable struct Project
    sources::Dict{AbstractPath, XTree}
    outputs::Dict{AbstractPath, XTree}
    rewriters::Vector{<:Rewriter}
end

function Project(rewriters)
    sources = merge(Dict{AbstractPath, XTree}(), [createsources!(rewriter) for rewriter in rewriters]...)
    outputs = Dict{AbstractPath, XTree}()
    return Project(sources, outputs, rewriters)
end


Base.show(io::IO, project::Project) = print(io, "Project($(length(project.sources)) documents, $(length(project.rewriters)) rewriters)")


"""
    rewritesources!(project, paths) -> paths

Rewrite source documents named by `paths` as well as new source documents
recursively created by rewriters. Return a list of all rewritten paths.
"""
function rewritesources!(project, paths = Set(keys(project.sources)))
    rewritesources!(project.sources, project.outputs, project.rewriters, paths)
end

function rewritesources!(sources::Dict, outputs::Dict, rewriters::Vector{<:Rewriter}, paths)
    dirtypaths = []
    docs = filter(((k, v),) -> k in paths, sources)

    while !isempty(docs)
        merge!(outputs, rewritedocs(docs, rewriters))
        docs = createsources!(rewriters)
        paths = union(paths, keys(docs))
    end

    rewriteoutputs!(Dict(p => outputs[p] for p in paths), rewriters)

    return paths
end


"""
    rewritedocs(sources, rewriters) -> outputs

Applies `rewriters` to a collection of `sources`.
"""
function rewritedocs(sources, rewriters)
    outputs = Dict{AbstractPath, XTree}()
    paths = collect(keys(sources))
    #Threads.@threads for i in 1:length(paths)
    for i in 1:length(paths)
        p = paths[i]
        xtree = sources[p]
        for rewriter in rewriters
            xtree = rewritedoc(rewriter, p, xtree)
        end
        outputs[p] = xtree
    end
    return outputs
end

function rewriteoutputs!(outputs, rewriters::Vector)
    for r in rewriters
        outputs = rewriteoutputs!(outputs, r)
    end
    outputs
end
rewriteoutputs!(outputs, rewriter::Rewriter) = outputs


"""
    createsources!(rewriters) -> sources

Creates new source documents from `rewriters`
"""
function createsources!(rewriters::Vector{<:Rewriter})
    docs = Vector{Dict{AbstractPath, XTree}}(undef, length(rewriters))
    docs = []
    Threads.@threads for i in 1:length(rewriters)
        #docs[i] = createsources!(rewriters[i])
        push!(docs, createsources!(rewriters[i]))
    end
    return merge(docs...)
end
#=

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
            xtree = rewritedoc(rewriter, p, xtree)
        end
        outputs[p] = xtree
        push!(dirtypaths, p)
    end

    # Apply project-level changes like updating tree elements,
    # and creating new files.
    newersources = Dict{AbstractPath, Node}()
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


=#
function reset!(project::Project)
    foreach(k -> delete!(project.sources, k), keys(project.sources))
    foreach(k -> delete!(project.outputs, k), keys(project.outputs))
    foreach(reset!, project.rewriters)
end
