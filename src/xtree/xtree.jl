abstract type XTree end


"""
    Leaf(value) <: XTree

A leaf node in an `XTree`. It holds a single value.
"""
struct Leaf{T} <: XTree
    data::T
end

Base.getindex(xleaf::Leaf) = xleaf.data

Leaf(leaf::Leaf) = leaf

AbstractTrees.children(::Leaf) = ()
AbstractTrees.printnode(io::IO, xleaf::Leaf) = print(io, xleaf[])
function AbstractTrees.printnode(io::IO, xleaf::Leaf{String})
    if get(io, :color, false) && !get(io, :compact, false)
        print(io, "$(crayon"green")\"$(xleaf[])\"$(crayon"reset")")
    else
        print(io, "\"$(xleaf[])\"")
    end

end


"""
    Node(tag, children...; attributes...)

A non-leaf node in an `XTree`. It has a tag, can hold a number of
children nodes and key-value attributes.

You can access and modify these using

- [`tag`](#) and [`withtag`](#)
- [`children`](#) and [`withchildren`](#)
- [`attributes`](#) and [`withattributes`](#)

## Examples

```julia
Node(:paragraph,
    "I am a sentence", "This one is short";
    class = "tight")

# Equivalently
Node(:paragraph,
    ["I am a sentence", "This one is short"],
    Dict(:class => "tight"))
```
"""
struct Node{T<:XTree, D<:Dict{Symbol}} <: XTree
    tag::Symbol
    children::Vector{T}
    attributes::D
end

Base.show(io::IO, xnode::Node) = print_tree(io, xnode, 3)

function Node(tag::Symbol, children...; attributes...)
    return Node(
        tag,
        [_xtree(x) for x in children],
        Dict(pairs(attributes)),
    )
end

Node(tag::Symbol, children::AbstractVector{<:XTree}) =
    Node(tag, children, Dict{Symbol, Any}())

_xtree(node::Node) = node
_xtree(leaf::Leaf) = leaf
_xtree(x) = Leaf(x)


AbstractTrees.children(xnode::Node) = xnode.children
tag(xnode::Node) = xnode.tag
attributes(xnode::Node) = xnode.attributes

Base.iterate(xnode::Node) = iterate(children(xnode))
Base.iterate(xnode::Node, state) = iterate(children(xnode), state)
Base.IteratorSize(::Type{Node{T}}) where T = Base.SizeUnknown()
Base.eltype(::Type{Node{T}}) where T = T

Base.eltype(::Type{<:TreeIterator{<:Node{T}}}) where T = T
Base.IteratorEltype(::Type{<:TreeIterator{<:Node{T}}}) where T = Base.HasEltype()

withchildren(xnode::Node, children) = Node(tag(xnode), children, attributes(xnode))
withtag(xnode::Node, tag) = Node(tag, children(xnode), attributes(xnode))
withattributes(xnode::Node, attributes) = Node(tag(xnode), children(xnode), attributes)


# Catamorphism

"""
    catafold(f, xtree, state)

Fold a function `f : (node, state) -> (node', state')` post-order over `xtree` and
return a modified tree as well as the resulting state.

Use [`cata`](#) for a stateless catamorphism and [`fold`](#) if you don't want to
transform `xtree`.
"""
function catafold(f, xnode::Node, state; T = XTree)
    cs = T[]
    for c in children(xnode)
        c, state = catafold(f, c, state; T = T)
        push!(cs, c)
    end
    return f(withchildren(xnode, cs), state)
end

catafold(f, xleaf::Leaf, state; kwargs...) = f(xleaf, state)

"""
    cata(f, tree)

Transform every node in `tree` with function `f`.
"""
cata(f, xnode::Node) = f(withchildren(xnode, XTree[cata(f, c) for c in children(xnode)]))
cata(f, xleaf::Leaf) = f(xleaf)


"""
    fold(f, tree)

Fold over tree in post-order iteration.

## Examples

```julia
node = Node(:table, Node(:row, 10, 10), Node(:row, 10, 10))
Pollen.fold(node, 0) do x, subtree
    subtree isa Leaf{Int} ? x + subtree[] : x
end
```
"""
fold(f, tree::XTree, init) = foldl(f, (l for l in PostOrderDFS(tree)); init = init)


"""
    fold(f, tree)

Fold over all leaves in `tree` in post-order iteration.

## Examples

```julia
node = Node(:table, Node(:row, 10, 10), Node(:row, 10, 10))
Pollen.foldleaves((x, leaf) -> x + leaf[], node, 0)
```
"""
foldleaves(f, xnode::XTree, init) = foldl(f, (l[] for l in Leaves(xnode)); init = init)

# Equality comparison for `Node`s and `Leaf`s. Short-circuits on the first mismatch.

function Base.:(==)(x1::Node, x2::Node)
    return ((tag(x1) == tag(x2)) &&
            (attributes(x1) == attributes(x2)) &&
            (length(children(x1)) == length(children(x2))) &&
            all(c1 == c2 for (c1, c2) in zip(children(x1), children(x2))))
end


Base.:(==)(::Node, _) = false
Base.:(==)(_, ::Node) = false

Base.:(==)(x1::Leaf, x2::Leaf) = x1[] == x2[]
Base.:(==)(::Leaf, _) = false
Base.:(==)(::Node, ::Leaf) = false
Base.:(==)(::Leaf, ::Node) = false


# Printing

function AbstractTrees.printnode(io::IO, x::Node)
    rich = get(io, :color, false) && !get(io, :compact, false)
    print(io, "Node(:")
    rich && print(io, crayon"bold")
    print(io, tag(x))
    rich && print(io, crayon"reset")
    if !isempty(x.attributes)
        print(io, "; ")
        rich && print(io, crayon"dark_gray")
        for (i, (key, value)) in enumerate(x.attributes)
            if i != 1
                print(io, ", ")
            end
            print(io, key, " = ")
            show(io, value)
        end
        rich && print(io, crayon"reset")
    end
    print(io, ")")
end


@testset "XTree" begin
    @testset "Node constructors" begin
        @test_nowarn Node(:tag)
        @test tag(Node(:tag)) == :tag
        @test isempty(children(Node(:tag)))
        @test isempty(attributes(Node(:tag)))
        @test_nowarn Node(:tag, [])
        @test_nowarn Node(:tag, Leaf.(1:10))
        @test Node(:tag, Leaf.(1:10)) == Node(:tag, (1:10)...)
    end

    @test_nowarn Leaf(1)
    @test_nowarn Leaf(Leaf(1)) isa Leaf{Int}

    @testset "with*" begin
        node = Node(:tag)
        @test tag(withtag(node, :gat)) == :gat
        @test length(children(withchildren(node, Leaf.(1:10)))) == 10
        @test attributes(withattributes(node, Dict(:x => "hi")))[:x] == "hi"
    end
end


@testset "fold" begin
    x = Node(:tag, Leaf.(1:10))
    @test foldleaves(+, x, 0) == sum(1:10)
    @test foldleaves(*, x, 1) == prod(1:10)
    x = Node(:tag, "Hello", "World")
    @test foldleaves(*, x, "") == "HelloWorld"
end


@testset "cata" begin
    x = Node(:tag, Leaf.(1:10))
    x_ = cata(x) do node
        if node isa Leaf
            return Leaf(-node[])
        else
            return node
        end
    end
    @test x_ == Node(:tag, Leaf.(-1:-1:-10))
end

@testset "catafold" begin
    x = Node(:tag, Leaf.(1:10))
    x_, n = catafold(x, 0) do node, state
        if node isa Leaf
            return Leaf(-node[]), state + 1
        else
            return node, state
        end
    end
    @test x_ == Node(:tag, Leaf.(-1:-1:-10))
    @test n == 10
end
