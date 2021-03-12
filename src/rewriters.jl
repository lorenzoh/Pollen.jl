
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


struct Replacer <: Rewriter
    fn
    selector::Selector
end

Base.show(io::IO, replacer::Replacer) = print(io, "Replacer($(replacer.selector))")

function updatefile(replace::Replacer, p::AbstractPath, doc::XTree)
    return cata(replace.fn, doc, replace.selector)
end


function RenderTemplate(template = TEMPLATE)
    return Replacer(doc -> rendertemplate(template, body = doc), SelectTag(:body))
end


function postbuild(rewriter, project, dst, format) end
