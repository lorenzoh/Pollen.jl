

function populatereferences!(references, doc::XExpr, linkfn = nothing, modules = ())
    sel = SelectTag(:a) & Pollen.SelectAttrEq(:href, "#")
    return map(doc, sel) do a
        # Get ref from <a><code>$ref</code></a>
        if isempty(a.children) || !(a.children[1] isa XExpr)
            return a
        end
        ref = a.children[1].children[1]
        res = Pollen.resolveidentifier(ref, modules)
        if isnothing(res)
            @info "Could not resolve reference $ref in modules $modules."
            return a
        end
        m, s = res
        fullref = "$m.$s"

        docs = get(references, fullref, getdocs(m, s))
        if isnothing(docs)
            @info "No docstrings found for reference `$fullref`."
            references[fullref] = nothing
        else
            references[fullref] = xexpr(docs)
        end
        if isnothing(linkfn)
            return a
        else
            return xexpr(
                a.tag,
                merge(a.attributes, Dict(:href => linkfn(fullref))),
                a.children
            )
        end
    end
end
