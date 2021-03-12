

struct Reference
    m::Module
    identifier::Union{Nothing, Symbol}
    fullname::String
    kind::Symbol
end

function Reference(m::Module, identifier::Symbol)
    return Reference(
        m,
        identifier,
        join((string(m), string(identifier)), '.'),
        referencetype(m, identifier)
    )
end


function referencetype(m::Module, identifier::Symbol)
    T = getfield(m, identifier)
    return referencetype(T)
end

function referencetype(x::DataType)
    isconcretetype(x) ? :struct : :type
end

function referencetype(x::UnionAll)
    isconcretetype(x) ? :pstruct : :ptype
end

function referencetype(::T) where T<:Function
    return :function
end

referencetype(x) = :const

referencetype(m::Module, ::Nothing = nothing) = :module

"""
    resolveidentifier(name, modules = ()) -> Union{Nothing, Reference}

Resolve an identifier `name` to a `Reference`. Return `nothing` if the identifier
can't be resolved in `Main` or `modules`.

```julia
resolveidentifier("sum", ("Base",)) == Reference(Base, :sum)
resolveidentifier("Base.sum") == Reference(Base, :sum)
```
"""
function resolveidentifier(name, modules = ())
    modulename, bindingname = splitidentifier(name)
    bindingsymbol = Symbol(bindingname)
    if modulename == ""
        for m in modules
            if isdefined(m, bindingsymbol)
                return Reference(m, bindingsymbol)
            end
        end
        return nothing
    else
        m = getmodule(modulename)
        return isnothing(m) ? nothing : Reference(m, bindingsymbol)
    end


end



function populatereferences!(references, doc::XNode, linkfn = nothing, modules = ())
    sel = SelectTag(:a) & Pollen.SelectAttrEq(:href, "#")
    return cata(doc, sel) do x
        refname = gettext(x)
        refname == "" && return x

        ref = resolveidentifier(refname, modules)
        if isnothing(ref)
            @info "Could not resolve reference $refname in modules $modules."
            return x
        else
            references[ref.fullname] = ref
            return XNode(
                :a,
                Dict(:href => "/" * linkfn(CommonMark.slugify(ref.fullname))),
                [XNode(:code, [XLeaf(ref.fullname)])],
            )
        end
    end
end
