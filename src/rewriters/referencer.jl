
mutable struct Referencer <: Rewriter
    references::Dict{String, Union{Reference, Nothing}}
    modules
    doc
    refdocs
    path
    linkfn
end

function Referencer(modules; path = p"REFERENCE")
    return Referencer(
        Dict{String, Union{Reference, Nothing}}(),
        modules,
        XNode(:body),
        Dict{String, XNode}(),
        Path("$path.html"),
        ref -> "$path/$(CommonMark.slugify(ref))",
    )
end


function updatefile(referencer::Referencer, ::AbstractPath, doc::XNode)
    doc = Pollen.populatereferences!(
        referencer.references,
        doc,
        referencer.linkfn,
        referencer.modules)
    return doc
end


function updatetree(referencer::Referencer, tree::FileTree)
    refdoc = buildreference(referencer)
    newfiles = Set()

    # Conditionally update/create reference page
    if refdoc != referencer.doc
        referencer.doc = refdoc
        push!(newfiles, (referencer.path, refdoc))
    end


    # Conditionally update/create binding pages
    for ref in values(referencer.references)
        doc = get(referencer.refdocs, ref.fullname, XNode(:null))
        newdoc = buildreferencepage(ref)
        if doc != newdoc
            referencer.refdocs[ref.fullname] = newdoc
            push!(newfiles, (Path(referencer.linkfn(ref.fullname)), newdoc))
        end
    end

    return tree, newfiles, Set()
end


function buildreference(referencer)
    refs = referencer.references
    children = [XNode(:h1, [XLeaf("Reference")])]

    for m in referencer.modules
        children = vcat(children,
            buildmodulereference(
                string(m),
                [ref for (k, ref) in refs if ref.m == m],
                referencer.linkfn))
    end
    return XNode(:body, children)
end


function buildmodulereference(mname, refs, linkfn)
    refs = sortrefs(refs)

    heading = XNode(:h2, [XLeaf(mname)])

    links = [
        XNode(
            :a,
            Dict(:href => linkfn(r.fullname)),
            [XNode(:code, [XLeaf(string(r.identifier))])]
        )
        for r in refs
    ]
    return [
        heading,
        XNode(:ul, [XNode(:li, [link]) for link in links])
    ]
end

function sortrefs(refs)
    return sort(refs, by = r -> (orderreftype(r.kind), string(r.identifier)))
end

orderreftype(reftype::Symbol) = ORDERREFTYPE[reftype]

const ORDERREFTYPE = Dict(
    :module => 1,
    :const => 2,
    :type => 3,
    :ptype => 4,
    :struct => 5,
    :pstruct => 6,
    :function => 7,

)


function buildreferencepage(ref::Reference)
    docs = getdocs(ref.m, ref.identifier)
    xdocs = if isnothing(docs)
        XNode(:p, [
            XLeaf("No documentation found for "),
            XNode(:code, [XLeaf(ref.fullname)]),
            XLeaf(".")
            ])
    else
        convert(XTree, docs)
    end
    return XNode(
        :body,
        [XNode(:article,
            [
                XNode(:h1, [XNode(:code, [XLeaf(ref.fullname)])]),
                xdocs,
            ],
        )]
    )
end
