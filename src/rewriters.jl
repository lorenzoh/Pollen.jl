
abstract type Rewriter end

"""
    updatefile(rewriter, p, doc) -> doc'

Rewrite `doc` at path `p`. Return rewritten `doc`.
"""
function updatefile(rewriter, p, doc)
    return doc
end


"""
    updatetree(rewriter, tree) -> (tree', newfiles, dirtypaths)

Return an updated `tree`, new `files` to be added and a set of
`dirtypaths` that were changed.
"""
function updatetree(::Rewriter, tree)
    return tree, Set(), Set()
end


struct Replace <: Rewriter
    fn
    selector::Selector
end

function updatefile(replace::Replace, p::AbstractPath, doc::XExpr)
    return map(x -> replace.fn(x), doc, replace.selector)
end


function RenderTemplate(template = TEMPLATE)
    return Replace(doc -> rendertemplate(template, body = doc), SelectTag(:body))
end
