# Filtered catamorphisms

"""
    cata(f, tree, selector)

Transform nodes matching `selector` with function `f`.
"""
function cata(f, tree, selector::Selector)
    return cata(tree) do x
        matches(selector, x) ? f(x) : x
    end
end

"""
    catafirst(f, tree, selector)

Like [`cate`](#), but apply `f` only to the first node that matches
`selector`.
"""
function catafirst(f, tree, selector::Selector)
    xtree_, _ = catafold(tree, false) do x, done
        (!done && matches(selector, x)) ? (f(x), true) : (x, done)
    end
    return xtree_
end

# Replace

"""
    replace(tree, xnode, selector)

Replace every node in `tree` that matches `selector` with `xnode`.
"""
function replace(tree, xnode, selector::Selector)
    cata(x -> xnode, tree, selector)
end

function replacefirst(tree, node, selector::Selector)
    return catafirst(x -> node, tree, selector)
end

function replacemany(xtree, xnodes, selector::Selector)
    xtree_, _ = catafold(xtree, 1) do x, i
        matches(selector, x) ? (xnodes[i], i + 1) : (x, i)
    end
    return xtree_
end

# Filter

function Base.filter(f, xtree::Node)
    return cata(xtree) do x
        if x isa Leaf
            return x
        else
            return withchildren(x, collect(filter(f, children(x))))
        end
    end
end

Base.filter(xtree::Node, sel::Selector) = filter(x -> matches(sel, x), xtree)

# Insertion

abstract type Position end

struct NthChild <: Position
    n::Int
    selector::Selector
end

FirstChild(selector) = NthChild(1, selector)

struct After <: Position
    selector::Selector
end

struct Before <: Position
    selector::Selector
end

function insert(xtree, x, pos::Position)
    cata(xtree) do child
        i = insertionindex(child, children(child), pos)
        if isnothing(i)
            return child
        else
            return withchildren(child, _insert(children(child), i, x))
        end
    end
end

function insertfirst(xtree, x, pos::Position)
    xtree_, inserted = catafold(xtree, false) do child, inserted
        inserted && return (child, inserted)
        i = insertionindex(child, children(child), pos)
        if isnothing(i)
            return child, false
        else
            return withchildren(child, _insert(children(child), i, x)), true
        end
    end
    return xtree_
end

function insertionindex(parent, children, pos::NthChild)
    matches(pos.selector, parent) ? pos.n : nothing
end

function insertionindex(parent, children, pos::Before)
    for (i, c) in enumerate(children)
        if matches(pos.selector, c)
            return i
        end
    end
    return nothing
end

function insertionindex(parent, children, pos::After)
    for (i, c) in enumerate(children)
        if matches(pos.selector, c)
            return i + 1
        end
    end
    return nothing
end

_insert(xs::AbstractVector{T}, i, x::T) where {T} = insert!(copy(xs), i, x)
_insert(xs::AbstractVector{<:XTree}, i, x::XTree) = vcat(xs[1:(i - 1)], [x], xs[i:end])

@testset "catafirst" begin
    x = Node(:body, [Leaf(1), Leaf(2)])

    x_ = cata(x, SelectLeaf()) do leaf
        return Leaf(leaf[] + 1)
    end
    @test children(x_)[1][] == 2
    @test children(x_)[2][] == 3

    x__ = catafirst(x, SelectLeaf()) do leaf
        return Leaf(leaf[] + 1)
    end
    @test children(x__)[1][] == 2
    @test children(x__)[2][] == 2
end

@testset "replace" begin
    x = Node(:body, [Leaf(1), Leaf(2)])
    node = Node(:body)
    @test Pollen.replace(x, node, SelectNode()) == node

    x_ = Pollen.replacefirst(x, node, SelectLeaf())
    @test tag(x_) == :body
    @test tag(children(x_)[1]) == :body
end

@testset "insert" begin
    x = Node(:body, [Leaf(1), Leaf(2)])
    @testset "NthChild" begin
        x_ = insert(x, Leaf(0), NthChild(1, SelectNode()))
        @test children(x_) == Leaf.(0:2)
        @test insert(x, Leaf(0), NthChild(1, SelectNode())) ==
              insertfirst(x, Leaf(0), NthChild(1, SelectNode()))
    end

    @testset "Before" begin
        x_ = insert(x, Leaf(0), Before(SelectLeaf()))
        @test children(x_) == Leaf.(0:2)
    end

    @testset "Before" begin
        x_ = insert(x, Leaf(0), After(SelectLeaf()))
        @test children(x_) == Leaf.([1, 0, 2])
    end
end

@testset "gettext" begin
    x = Node(:body, Leaf.(["Hello", " ", "World"]))
    @test Pollen.gettext(x) == "Hello World"
end
