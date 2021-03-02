

"""
    DocumentTree()

Rewriter that adds a document tree to each document that allows
navigating to other pages in the project. For all documents `doc`
with `filterfn(doc) == true`, the document tree is inserted after
first element selected by selector `after`. The tree is constructed
by passing `project.srctree` to `buildfn`.
"""
mutable struct DocumentTree <: Rewriter
    doc
    after::Selector
    filterfn
    buildfn
end

function DocumentTree()
    return DocumentTree(nothing, SelectTag(:article), p -> true, builddoctree)
end


function updatetree(doctree::DocumentTree, tree::FileTree)
    newdoc = doctree.buildfn(tree)
    isdirty = newdoc == doctree.doc
    doctree.doc = newdoc
    dirtypaths = []

    tree = map(tree, dirs = false) do f
        doctree.filterfn(path(f)) || return f
        isdirty && push!(dirtypaths, path(f))
        doc = f[]
        if isnothing(selectfirst(doc, SelectTag(:doctree)))
            return setvalue(f, insertafter(doctree.after, doc, newdoc))
        else
            return setvalue(f, replacefirst(doc, newdoc, SelectTag(:doctree)))
        end
    end
    return tree, Set(), dirtypaths
end

builddoctree(tree) = xexpr(:doctree, _builddoctree(tree))

function _builddoctree(tree::FileTree)
    return xexpr(:ul, tree.name, [_builddoctree(c) for c in tree.children]...)
end


function _builddoctree(file::File)
    link = xexpr(:a, Dict(:href => nodehref(file)), file.name)
    return xexpr(:li, link)
end
