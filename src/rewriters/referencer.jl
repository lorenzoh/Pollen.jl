
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
        Node(:body),
        Dict{String, Node}(),
        Path(path),
        ref -> "$path/$ref",
    )
end


function rewritedoc(referencer::Referencer, ::AbstractPath, doc::Node)
    doc = populatereferences!(
        referencer.references,
        doc,
        referencer.linkfn,
        referencer.modules)
    return doc
end


function createsources!(referencer::Referencer)
    refdoc = buildreference(referencer)
    docs = Dict{AbstractPath, Node}()

    # Conditionally update/create reference page
    if refdoc != referencer.doc
        referencer.doc = refdoc
        docs[referencer.path] =  refdoc
    end


    # Conditionally update/create binding pages
    l = ReentrantLock()
    #Threads.@threads for ref in collect(values(referencer.references))
    for ref in [v for v in values(referencer.references)]
        doc = get(referencer.refdocs, ref.fullname, nothing)
        if isnothing(doc)
            newdoc = buildreferencepage(ref)
            lock(l) do
                referencer.refdocs[ref.fullname] = newdoc
                docs[Path(referencer.linkfn(ref.fullname))] = newdoc
            end
        end
    end

    return docs
end

function reset!(referencer::Referencer)
    referencer.references = Dict{String, Union{Reference, Nothing}}()
    referencer.doc = Node(:body)
    referencer.refdocs = Dict{String, Node}()
    return
end


function buildreference(referencer)
    refs = referencer.references
    children = [Node(:h1, [Leaf("Reference")])]

    ms = sort(unique([ref.m for ref in values(referencer.references)]), by = string)

    for m in referencer.modules
        children = vcat(children,
            buildmodulereference(
                string(m),
                [ref for (k, ref) in refs if ref.m == m],
                referencer.linkfn))
    end
    return Node(:body, children)
end


function buildmodulereference(mname, refs, linkfn)
    refs = sortrefs(refs)

    heading = Node(:h2, [Leaf(mname)])

    links = [
        Node(
            :a,
            Dict(:href => linkfn(r.fullname)),
            [Node(:code, [Leaf(string(r.identifier))])]
        )
        for r in refs
    ]
    return [
        heading,
        Node(:ul, [Node(:li, [link]) for link in links])
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
        Node(:p, XTree[
            Leaf("No documentation found for "),
            Node(:code, [Leaf(ref.fullname)]),
            Leaf(".")
            ])
    else
        convert(XTree, docs)
    end
    if !isnothing(ref.identifier) && ref.kind in (:struct, :function)
        push!(xdocs.children, Node(:h2, [Leaf("Methods")]))
        push!(xdocs.children, Leaf(methods(getfield(ref.m, ref.identifier))))
    end
    return Node(
        :body,
        [Node(:article,
            [
                Node(:h1, [Node(:code, [Leaf(ref.fullname)])]),
                xdocs,
            ],
        )]
    )
end
