
"""
    abstract type Selector

A `Selector` matches a node in an `XTree`. Selectors can be passed
to [`select`](#), [`selectfirst`](#), [`cata`](#).

See `subtypes(Selector)` for example selectors.

## Extending

To implement a `Selector`:

- write a `struct MySelector <: Selector`
- implement a method `Pollen.matches(::MySelector, ::XTree)::Bool`

"""
abstract type Selector end

matches(sel::Selector, x) = false

"""
    SelectCondition(f) <: Selector

Selects all nodes or leaves for which function `f` returns `true`.
"""
struct SelectCondition <: Selector
    f::Any
end
matches(sel::SelectCondition, x) = sel.f(x)

"""
    SelectAll() <: Selector

Selects every node and leaf.
"""
struct SelectAll <: Selector end
matches(::SelectAll, x) = true

"""
    SelectNode() <: Selector

Selects every [`Node`](#).
"""
struct SelectNode <: Selector end
matches(::SelectNode, ::Node) = true
matches(::SelectNode, _) = false

struct SelectLeaf <: Selector end
matches(::SelectLeaf, ::Leaf) = true
matches(::SelectLeaf, _) = false

struct SelectTag <: Selector
    tag::Symbol
end

matches(sel::SelectTag, x::Node) = sel.tag == tag(x)

struct SelectOr{T <: Tuple} <: Selector
    selectors::T
end

Base.:(|)(sel1::Selector, sel2::Selector) = SelectOr((sel1, sel2))
Base.:(|)(selor::SelectOr, sel::Selector) = SelectOr((selor.seletors..., sel))

matches(sel::SelectOr, x) = any(matches(s, x) for s in sel.selectors)

struct SelectAnd{T <: Tuple} <: Selector
    selectors::T
end

Base.:(&)(sel1::Selector, sel2::Selector) = SelectAnd((sel1, sel2))
Base.:(&)(seland::SelectAnd, sel::Selector) = SelectAnd((seland.selectors..., sel))

matches(sel::SelectAnd, x) = all(matches(s, x) for s in sel.selectors)

"""
    SelectNot(selector)

Inverts a selector. Use `!selector` as a shorthand, e.g. `!SelectTag(:div)`.
"""
struct SelectNot <: Selector
    sel::Selector
end
matches(sel::SelectNot, x) = !matches(sel.sel, x)

Base.:(!)(sel::Selector) = SelectNot(sel)

"""
    SelectAttrEq(name, value)

Selects nodes with `attributes(node)[name] == val`.
"""
struct SelectAttrEq{T} <: Selector
    attr::Symbol
    val::T
end

function matches(sel::SelectAttrEq, node::Node)
    haskey(attributes(node), sel.attr) && attributes(node)[sel.attr] == sel.val
end

"""
    SelectHasAttr(name)

Selects nodes that have an attribute `name`.
"""
struct SelectHasAttr <: Selector
    attr::Symbol
end

matches(sel::SelectHasAttr, x::Node) = haskey(attributes(x), sel.attr)

## API

"""
    select(tree, selector)

Iterate over nodes in `tree` that match `selector`.
Call `collect` on the iterator to get a vector of results.

## Examples

{cell=select}
```julia
using Pollen
node = Node(:document, "Title", Node(:p, "Hello ", "there."))
select(node, Pollen.SelectLeaf()) |> collect
```
"""
select(xtree::XTree, sel::Selector) = (x for x in PostOrderDFS(xtree) if matches(sel, x))

"""
    selectfirst(tree, selector)

Iterate over nodes in `tree` that match `selector` and return
the first one. If no matching node can be found, return `nothing`.
"""
function selectfirst(xtree::XTree, sel::Selector)
    for x in PostOrderDFS(xtree)
        if matches(sel, x)
            return x
        end
    end
    return nothing
end

@testset "Selectors" begin
    leaf = Leaf(1)
    node = Node(:body, [leaf, Leaf(2)], Dict(:class => "content"))

    @test matches(SelectTag(:body), node)
    @test !matches(SelectTag(:div), node)
    @test matches(!SelectTag(:div), node)
    @test matches(SelectTag(:div) | SelectTag(:body), node)
    @test !matches(SelectTag(:div) & SelectTag(:body), node)
    @test matches(SelectLeaf(), leaf)
    @test matches(SelectNode(), node)
    @test matches(SelectHasAttr(:class), node)
    @test matches(SelectAttrEq(:class, "content"), node)

    @testset "select" begin
        @test length(collect(select(node, SelectAll()))) == 3
        @test selectfirst(node, SelectLeaf()) === leaf
    end
end
