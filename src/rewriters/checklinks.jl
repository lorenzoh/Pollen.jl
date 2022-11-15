
struct CheckLinks <: Rewriter
    ids::Set{String}
    sel::Selector
end

"""
    CheckLinks() <: Rewriter

A [`Rewriter`](#) that warns when it finds a `:reference` tag that does not
point to a valid document. See [`ResolveReferences`](#) and [`ResolveSymbols`](#)
for rewriters that create nodes with `:reference` tags.

It does not make any changes to a project.

## Example

```julia
Project([ResolveReferences(), CheckLinks()])
```
"""
CheckLinks() = CheckLinks(
    Set{String}(),
    SelectReference(),
)

function rewriteoutputs!(outputs, check::CheckLinks)
    foreach(keys(outputs)) do id
        push!(check.ids, id)
    end

    for (id, doc) in outputs
        for node in select(doc, check.sel)
            target = get(attributes(node), :document_id, nothing)
            if !(target in check.ids)
                # Necessary until notes in resolvereferences.jl are implemented
                target == "@ref" && continue
                startswith(splitpath(target)[end], "#") && continue
                @warn "Found an internal link that points to a non-existant document:" source_document_id=id broken_link_node=node
            end
        end
    end
    return outputs
end
