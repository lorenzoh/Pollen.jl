struct DocumentGraph <: Rewriter
    graph::Any
end

function DocumentGraph()
    g = MetaDiGraph(SimpleDiGraph(0))
    set_prop!(g, :idxs, Dict{String,Int}())
    return DocumentGraph(g)
end


function rewriteoutputs!(docdict, docgraph::DocumentGraph)
    g = docgraph.graph
    idxs = get_prop(g, :idxs)

    # Add new documents to graph
    for (p, doc) in docdict
        name = string(p)
        if !haskey(idxs, name)
            @assert add_vertex!(g)
            v = nv(g)
            idxs[name] = v
            set_prop!(g, v, :docid, string(p))
            set_prop!(g, v, :title, get(attributes(doc), :title, string(v)))
            set_prop!(g, v, :tag, tag(doc))
        end
    end


    # Add edges
    for (p, doc) in docdict
        _addrefedges!(g, doc, p)
    end

    for (p, doc) in docdict
        v = get_prop(g, :idxs)[string(p)]
        attrs = attributes(doc)
        attrs[:backlinks] = [backlinkdata(g, v_) for v_ in inneighbors(g, v) if v_ != v]
    end

    return docdict
end

function backlinkdata(g, v_)
    d = props(g, v_)
    return d
end


function _documentgraph(docdict)
    paths, docs = keys(docdict), collect(values(docdict))
    idxs = Dict(string(p) => i for (i, p) in enumerate(paths))
    g = MetaDiGraph(SimpleDiGraph(length(idxs)))
    set_prop!(g, :idxs, idxs)
    for (p, i) in idxs
        set_prop!(g, i, :docid, p)
        set_prop!(g, i, :title, get(attributes(docs[i]), :title, string(i)))
        set_prop!(g, i, :tag, tag(docs[i]))
    end
    return g
end



function _addrefedges!(g, doc, path)
    idxs = get_prop(g, :idxs)
    v = idxs[string(path)]
    for ref in select(doc, SelectReference())
        target = attributes(ref)[:document_id]
        v_ = get(idxs, string(target), nothing)
        isnothing(v_) && continue
        add_edge!(g, v, v_)
    end
end


function _findreferences(doc)
    refs = Set{FilePathsBase.PATH_TYPES[1]}()

    for xref in select(doc, SelectDocumentReference())
        @show attributes(xref)[:document_id]
        push!(refs, Path(attributes(xref)[:document_id]))
    end
    for xref in select(doc, SelectSymbolReference())
        document_id = attributes(xref)[:document_id]
        push!(refs, document_id)
    end
    return refs
end
