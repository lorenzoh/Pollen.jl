

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
    return XNode(:docs, [convert(XTree, v) for v in values(md.docs)])
end

function Base.convert(::Type{XTree}, doc::Base.Docs.DocStr)
    s = collect(doc.text)[1]
    xdoc = Pollen.parse(s, Pollen.Markdown())
    return XNode(:doc, doc.data, children(xdoc))
end
