struct Backlinks <: Rewriter
    graph::Any
end

Base.show(io::IO, ::Backlinks) = print(io, "Backlinks()")

"""
    Backlinks() <: Rewriter

[`Rewriter`](#) that sets the `:backlinks` attribute of every page in a project
with a list of page IDs that link to it.

A page links to another page with id `id` if it has a `Node(:reference, ...)`
with attribute `:document_id = id`. See [`ResolveReferences`](#) and [`ResolveSymbols`](#)
for rewriters that create nodes with `:reference` tags.
"""
function Backlinks()
    g = MetaDiGraph(SimpleDiGraph(0))
    set_prop!(g, :idxs, Dict{String, Int}())
    return Backlinks(g)
end

@option struct ConfigBacklinks<: AbstractConfig end
configtype(::Type{Backlinks}) = ConfigBacklinks
from_config(::ConfigBacklinks) = Backlinks()


function rewriteoutputs!(docdict, docgraph::Backlinks)
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

    for (docid, doc) in docdict
        v = get_prop(g, :idxs)[docid]
        docdict[docid] = withattributes(doc,
                                        merge(attributes(doc),
                                              Dict(:backlinks => [backlinkdata(g, v_)
                                                                  for v_ in inneighbors(g,
                                                                                        v)
                                                                  if v_ != v])))
    end

    return docdict
end

function backlinkdata(g, v_)
    d = props(g, v_)
    return d
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

SelectReference() = SelectTag(:reference) & SelectHasAttr(:document_id)
SelectSymbolReference() = SelectReference() & SelectAttrEq(:reftype, "symbol")
SelectDocumentReference() = SelectReference() & SelectAttrEq(:reftype, "document")
