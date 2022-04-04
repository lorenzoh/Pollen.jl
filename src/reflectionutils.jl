

function splitidentifier(identifier)
    parts = split(identifier, '.')
    modulename = join(parts[1:end-1], '.')
    bindingname = Symbol(parts[end])
    return modulename, bindingname
end


const MODNAMES = Ref(string.(Base.Docs.modules))


function getmodule(s::String)
    # Refresh `MODNAMES`
    if length(Base.Docs.modules) != length(MODNAMES[])
        MODNAMES[] = string.(Docs.modules)
    end
    idx = findfirst(MODNAMES[] .== s)
    return isnothing(idx) ? nothing : Docs.modules[idx]
end


function getdocs(m::Module, s::Symbol)
    bs = [(b, md) for (b, md) in Docs.meta(m)]
    bindingnames = [b.var for (b, _) in bs]
    idx = findfirst(bindingnames .== s)
    return isnothing(idx) ? nothing : bs[idx][2]
end


# Conversion to x-expressions


function Base.convert(::Type{XTree}, md::Base.Docs.MultiDoc)
    return Node(:docs, XTree[convert(XTree, v) for v in values(md.docs)])
end

function Base.convert(::Type{XTree}, doc::Base.Docs.DocStr)
    s = collect(doc.text)[1]
    # Parse from docstring and filter out redundant line breaks
    xdoc = replace(Pollen.parse(s, Pollen.MarkdownFormat()), Leaf("\n"), SelectTag(:br))
    return Node(:doc, doc.data, children(xdoc))
end
