
"""
    resolveidentifier(ref::String, modules = ())

resolveidentifier("sum", ("Base",)) == (Base, :sum)
resolveidentifier("Base.sum") == (Base, :sum)
"""
function resolveidentifier(identifier::String, modules = ())
    modulename, bindingname = splitidentifier(identifier)
    bindingsymbol = Symbol(bindingname)
    if modulename == ""
        for m in modules
            if isdefined(m, bindingsymbol)
                return m, bindingsymbol
            end
        end
        return nothing
    else
        m = getmodule(modulename)
        return isnothing(m) ? nothing : (m, bindingsymbol)
    end
end


function splitidentifier(identifier)
    parts = split(identifier, '.')
    modulename = join(parts[1:end-1], '.')
    bindingname = Symbol(parts[end])
    return modulename, bindingname
end


const MODNAMES = Ref(string.(Base.Docs.modules))


function getmodule(s::String)
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


function Pollen.xexpr(md::Base.Docs.MultiDoc)
    return xexpr(:docs, collect(values(md.docs))...)
end

function Pollen.xexpr(doc::Base.Docs.DocStr)
    s = collect(doc.text)[1]
    xdoc = Pollen.parse(s, Pollen.Markdown())
    return xexpr(:doc, doc.data, xdoc.children...)
end
