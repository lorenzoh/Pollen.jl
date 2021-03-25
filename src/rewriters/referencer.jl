
mutable struct Referencer <: Rewriter
    references::Dict{String, Union{Reference, Nothing}}
    modules
    doc
    refdocs
    path
    linkfn
end

Base.show(io::IO, referencer::Referencer) = print(io, "Referencer($(Tuple(referencer.modules)), $(length(referencer.references)) references)")

function Referencer(modules; path = p"REFERENCE")
    return Referencer(
        Dict{String, Union{Reference, Nothing}}(),
        modules,
        XNode(:body),
        Dict{String, XNode}(),
        Path(path),
        ref -> "$path/$ref",
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


function createdocs(referencer::Referencer)
    refdoc = buildreference(referencer)
    docs = Dict{AbstractPath, XNode}()

    # Conditionally update/create reference page
    if refdoc != referencer.doc
        referencer.doc = refdoc
        docs[referencer.path] =  refdoc
    end


    # Conditionally update/create binding pages
    Threads.@threads for ref in collect(values(referencer.references))
        doc = get(referencer.refdocs, ref.fullname, nothing)
        if isnothing(doc)
            newdoc = buildreferencepage(ref)
            referencer.refdocs[ref.fullname] = newdoc
            docs[Path(referencer.linkfn(ref.fullname))] = newdoc
        end
    end

    return docs
end

function reset!(referencer::Referencer)
    referencer.references = Dict{String, Union{Reference, Nothing}}()
    referencer.doc = XNode(:body)
    referencer.refdocs = Dict{String, XNode}()
    return
end


function buildreference(referencer)
    refs = referencer.references
    children = [XNode(:h1, [XLeaf("Reference")])]

    ms = sort(unique([ref.m for ref in values(referencer.references)]), by = string)

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
        XNode(:p, XTree[
            XLeaf("No documentation found for "),
            XNode(:code, [XLeaf(ref.fullname)]),
            XLeaf(".")
            ])
    else
        convert(XTree, docs)
    end
    if !isnothing(ref.identifier) && ref.kind in (:struct, :function)
        push!(xdocs.children, XNode(:h2, [XLeaf("Methods")]))
        push!(xdocs.children, XLeaf(methods(getfield(ref.m, ref.identifier))))
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
