
abstract type Selector end

matches(sel::Selector, x) = false

struct SelectCond <: Selector
    f
end
matches(sel::SelectCond, x) = sel.f(x)

struct SelectAll <: Selector end
matches(::SelectAll, x) = true

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

struct SelectOr{T<:Tuple} <: Selector
    selectors::T
end

Base.:(|)(sel1::Selector, sel2::Selector) = SelectOr((sel1, sel2))
Base.:(|)(selor::SelectOr, sel::Selector) = SelectOr((selor.seletors..., sel))

matches(sel::SelectOr, x) = any(matches(s, x) for s in sel.selectors)

struct SelectAnd{T<:Tuple} <: Selector
    selectors::T
end

Base.:(&)(sel1::Selector, sel2::Selector) = SelectAnd((sel1, sel2))
Base.:(&)(seland::SelectAnd, sel::Selector) = SelectAnd((seland.selectors..., sel))


matches(sel::SelectAnd, x) = all(matches(s, x) for s in sel.selectors)

struct SelectNot <: Selector
    sel::Selector
end
matches(sel::SelectNot, x) = !matches(sel.sel, x)

Base.:(!)(sel::Selector) = SelectNot(sel)

"""
    SelectAttrEq(attr, val)

Select an x-expression with attribute `attr == val`
"""
struct SelectAttrEq{T} <: Selector
    attr::Symbol
    val::T
end

matches(sel::SelectAttrEq, x::Node) = get(attributes(x), sel.attr, nothing) == sel.val

struct SelectHasAttr <: Selector
    attr::Symbol
end

matches(sel::SelectHasAttr, x::Node) = haskey(attributes(x), sel.attr)


## API

select(xtree::XTree, sel::Selector) = (x for x in PostOrderDFS(xtree) if matches(sel, x))

function selectfirst(xtree::XTree, sel::Selector)
    for x in PostOrderDFS(xtree)
        if matches(sel, x)
            return x
        end
    end
    return nothing
end



@testset "Selectors" begin
    node = Node(:body, [Leaf(1), Leaf(2)], Dict(:class => "content"))
    leaf = children(node)[1]
    @test matches(SelectTag(:body), node)
    @test !matches(SelectTag(:div), node)
    @test matches(!SelectTag(:div), node)
    @test matches(SelectTag(:div) | SelectTag(:body), node)
    @test matches(SelectLeaf(), leaf)
    @test matches(SelectNode(), node)
    @test matches(SelectHasAttr(:class), node)
    @test matches(SelectAttrEq(:class, "content"), node)
end
