abstract type XTree end

struct XNode{T<:XTree, V} <: XTree
    tag::Symbol
    attributes::Dict{Symbol, V}
    children::Vector{T}
end

Base.show(io::IO, xnode::XNode) = print_tree(io, xnode, 3)

XNode(tag::Symbol) = XNode(tag, XTree[])
XNode(tag::Symbol, attributes::Dict) = XNode(tag, attributes, XTree[])
XNode(tag::Symbol, children::Vector) = XNode(tag, Dict{Symbol, Any}(), children)

AbstractTrees.children(xnode::XNode) = xnode.children
tag(xnode::XNode) = xnode.tag
attributes(xnode::XNode) = xnode.attributes

Base.iterate(xnode::XNode) = iterate(children(xnode))
Base.iterate(xnode::XNode, state) = iterate(children(xnode), state)
Base.IteratorSize(::Type{XNode{T}}) where T = Base.SizeUnknown()
Base.eltype(::Type{XNode{T}}) where T = T

Base.eltype(::Type{<:TreeIterator{XNode{T}}}) where T = T
Base.IteratorEltype(::Type{<:TreeIterator{XNode{T}}}) where T = Base.HasEltype()

withchildren(xnode::XNode, children) = XNode(tag(xnode), attributes(xnode), children)
withtag(xnode::XNode, tag) = XNode(tag, attributes(xnode), children(xnode))
withattributes(xnode::XNode, attributes) = XNode(tag(xnode), attributes, children(xnode))


struct XLeaf{T} <: XTree
    data::T
end

Base.getindex(xleaf::XLeaf) = xleaf.data


AbstractTrees.children(::XLeaf) = ()
AbstractTrees.printnode(io::IO, xleaf::XLeaf) = print(io, xleaf[])

# Catamorphism

"""
    catafold(f, xtree, state)

Fold a function `f : (node, state) -> (node', state')` post-order over `xtree` and
return a modified tree as well as the resulting state.

Use [`cata`](#) for a stateless catamorphism and [`fold`](#) if you don't want to
transform `xtree`.
"""
function catafold(f, xnode::XNode, state; T = XTree)
    cs = T[]
    for c in children(xnode)
        c, state = catafold(f, c, state; T = T)
        push!(cs, c)
    end
    return f(withchildren(xnode, cs), state)
end

catafold(f, xleaf::XLeaf, state; kwargs...) = f(xleaf, state)

"""
    cata(f, xtree)

Replace every node or leaf `v` in `xtree` with `f(v)`. Traverses in
post-order.
"""
cata(f, xnode::XNode) = f(withchildren(xnode, XTree[cata(f, c) for c in children(xnode)]))
cata(f, xleaf::XLeaf) = f(xleaf)


fold(f, xnode::XTree, init) = foldl(f, (l for l in PostOrderDFS(xnode)); init = init)
foldleaves(f, xnode::XTree, init) = foldl(f, (l[] for l in Leaves(xnode)); init = init)

function Base.:(==)(x1::XNode, x2::XNode)
    return ((tag(x1) == tag(x2)) &&
            (attributes(x1) == attributes(x2)) &&
            (length(children(x1)) == length(children(x2))) &&
            all(c1 == c2 for (c1, c2) in zip(children(x1), children(x2))))
end


Base.:(==)(::XNode, _) = false
Base.:(==)(_, ::XNode) = false

Base.:(==)(x1::XLeaf, x2::XLeaf) = x1[] == x2[]
Base.:(==)(::XLeaf, _) = false
Base.:(==)(::XNode, ::XLeaf) = false
Base.:(==)(::XLeaf, ::XNode) = false


# Showing

function AbstractTrees.printnode(io::IO, x::XNode)
    print(io, ":", x.tag)
    if !isempty(x.attributes)
        print(io, " [")
        for (i, (key, value)) in enumerate(x.attributes)
            if i != 1
                print(io, ", ")
            end
            print(io, key, " = ", value)
        end
        print(io, "]")
    end
end
