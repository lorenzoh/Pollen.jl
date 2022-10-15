
struct CheckLinks <: Rewriter
    sel::Selector
end

CheckLinks() = CheckLinks(SelectTag(:reference) & SelectHasAttr(:document_id))

function rewriteoutputs!(outputs, check::CheckLinks)
    for (id, doc) in outputs
        for node in select(doc, check.sel)
            target = get(attributes(node), :document_id, nothing)
            if !(target in keys(outputs))
                # Necessary until notes in resolvereferences.jl are implemented
                target == "@ref" && continue
                startswith(splitpath(target)[end], "#") && continue
                @warn "Found an internal link that points to a non-existant document:" source_document_id=id broken_link_node=node
            end
        end
    end
    return outputs
end
