
"""
    Project(rewriters)

A project manages the loading, parsing and rewriting of a set of
documents.

"""
struct Project
    sources::ThreadSafeDict{String, Node}
    outputs::ThreadSafeDict{String, Node}
    rewriters::Vector{<:Rewriter}
end

function Project(rewriters)
    sources = ThreadSafeDict{String, Node}()
    foreach(rewriters) do rewriter
        merge!(sources, createsources!(rewriter))
    end
    outputs = ThreadSafeDict{String, Node}()
    return Project(sources, outputs, rewriters)
end

function Base.show(io::IO, project::Project)
    print(io,
          "Project($(length(project.sources)) documents, $(length(project.rewriters)) rewriters)")
end

"""
    rewritesources!(project, docids) -> rewritten_docids

Rewrite source documents named by `docids` as well as new source documents
recursively created by rewriters. Return a list of all rewritten document ids.
"""
function rewritesources!(project::Project, docids = Set(keys(project.sources)))
    rewritesources!(project.sources, project.outputs, project.rewriters, docids)
end

function rewritesources!(sourcedocs, outputdocs, rewriters::Vector{<:Rewriter}, docids)
    docs = filter(((k, v),) -> k in docids, sourcedocs)

    while !isempty(docs)
        merge!(outputdocs, rewritedocs(docs, rewriters))
        docs = createsources!(rewriters)
        docids = union(docids, keys(docs))
    end

    merge!(outputdocs,
           rewriteoutputs!(Dict{String, Any}(docid => outputdocs[docid] for docid in docids),
                           rewriters))

    return docids
end

"""
    rewritedocs(sources, rewriters) -> outputs

Applies `rewriters` to a collection of `sources`.
"""
function rewritedocs(sources, rewriters)
    outputs = ThreadSafeDict{String, XTree}()
    docids = collect(keys(sources))
    Threads.@threads for i in eachindex(docids)
        docid = docids[i]
        doc = sources[docid]
        foreach(rewriters) do rewriter
            doc = rewritedoc(rewriter, docid, doc)
        end
        outputs[docid] = doc
    end
    return outputs
end

function rewriteoutputs!(outputs, rewriters::Vector)
    for r in rewriters
        outputs = rewriteoutputs!(outputs, r)
    end
    outputs
end
rewriteoutputs!(outputs, ::Rewriter) = outputs

"""
    createsources!(rewriters) -> sources

Creates new source documents from `rewriters`
"""
function createsources!(rewriters::Vector{<:Rewriter})
    docs = Vector{Dict{String, Node}}(undef, length(rewriters))
    Threads.@threads for i in 1:length(rewriters)
        docs[i] = createsources!(rewriters[i])
    end
    return merge(docs...)
end

function reset!(project::Project)
    foreach(k -> delete!(project.sources, k), keys(project.sources))
    foreach(k -> delete!(project.outputs, k), keys(project.outputs))
    foreach(reset!, project.rewriters)
end

@testset "Project" begin
    # sources are loaded on project creation

    # reset! works

    # createsources! is idempotent
end
