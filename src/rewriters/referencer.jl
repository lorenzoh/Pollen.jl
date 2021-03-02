
mutable struct Referencer <: Rewriter
    references::Dict{String, Union{XExpr, Nothing}}
    modules
    doc
    path
    linkfn
end

function Referencer(modules...; path = p"REFERENCE")
    return Referencer(
        Dict{String, Union{XExpr, Nothing}}(),
        modules,
        xexpr(:body),
        path,
        ref -> "/$path#$ref",
    )
end


function updatefile(referencer::Referencer, ::AbstractPath, doc::XExpr)
    doc = Pollen.populatereferences!(
        referencer.references,
        doc,
        referencer.linkfn,
        referencer.modules)
    return doc
end


function updatetree(referencer::Referencer, tree::FileTree)
    refdoc = buildreferencedoc(referencer.references)
    if refdoc == referencer.doc
        return tree, Set(), Set()
    else
        referencer.doc = refdoc
        return tree, [(referencer.path, referencer.doc)], []
    end


    return tree, newfiles, []
end


function buildreferencedoc(references)
    return xexpr(:body, xexpr(:h1, "References"))
end
