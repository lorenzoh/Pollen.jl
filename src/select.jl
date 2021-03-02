# Selectors for nodes in `XExpr`s.



#=
select(doc, "pre[lang='julia']")

SelectTag(:pre) & SelectAttributeEq(:lang, "julia")


select(doc, "h1, h2, h3, h4")

SelectTag(:h1) | SelectTag(:h2) | SelectTag(:h3) | SelectTag(:h4)

=#

# Selectors

abstract type Selector end

matches(sel::Selector, x) = false

struct SelectCond <: Selector
    f
end
matches(sel::SelectCond, x) = sel.f(x)

struct SelectAll <: Selector end
matches(sel::SelectAll, x) = true

struct SelectTag <: Selector
    tag::Symbol
end

matches(sel::SelectTag, x::XExpr) = sel.tag == x.tag

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
Base.:(&)(seland::SelectAnd, sel::Selector) = SelectAnd((seland.seletors..., sel))


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

matches(sel::SelectAttrEq, x::XExpr) = get(x.attributes, sel.attr, nothing) == sel.val


# Traversal

function traverse(doc::XExpr; ordering = PostOrderDFS)
    return (x for x in ordering(doc) if x isa XExpr)
end

# Select


function select(doc::XExpr, sel::Selector; ordering = PreOrderDFS)
    return (x for x in traverse(doc; ordering = ordering) if matches(sel, x))
end


function selectfirst(doc::XExpr, sel::Selector; ordering = PreOrderDFS)
    for x in traverse(doc; ordering = ordering)
        if matches(sel, x)
            return x
        end
    end
    return nothing
end

function Base.map(f, doc::XExpr, sel::Selector)
    return fold(doc, nothing) do x, s
        return matches(sel, x) ? (f(x), nothing) : (x, nothing)
    end |> first
end

#= Tree operations

`selectfirst(doc, sel)`
`replacefirst(doc, sel)`

- traverse tree


`insertbefore(doc, subdoc, sel)`
`insertafter(doc, subdoc, sel)`
`groupchildren(doc, sel)`


=#
function fold(f, doc::XExpr, state)
    children = []
    for child in doc.children
        child, state = fold(f, child, state)
        push!(children, child)
    end
    return f(xexpr(doc.tag, doc.attributes, children), state)
end

function Base.foreach(f, doc::XExpr, sel::Selector; kwargs...)
    for x in traverse(doc; kwargs...)
        if matches(sel, x)
            f(x)
        end
    end
end

function mapfirst(f, doc::XExpr, sel::Selector)
    return fold(doc, false) do x, hasreplaced
        hasreplaced && return (x, true)
        matches(sel, x) ? (f(x), true) : (x, false)
    end |> first
end

replacefirst(doc, x, sel) = mapfirst(_ -> x, doc, sel)

function foldchildren(f, doc::XExpr, state)
    children = []
    for child in doc.children
        if child isa XExpr
            child, state = foldchildren(f, child, state)
        end
        push!(children, child)
    end
    children, state = f(children, state)

    return xexpr(doc.tag, doc.attributes, children...), state
end

fold(f, val, state) = f(val, state)


"""
    insertafter(sel, doc::XExpr, child)

Insert `child` into `doc` after the first match of `sel`.
"""
function insertafter(sel, doc::XExpr, child)
    return foldchildren(doc, false) do children, inserted
        # only insert once
        if inserted
            return children, true
        # insert into children after match
        else
            matchidx = findfirst([matches(sel, c) for c in children])
            if isnothing(matchidx)
                return children, false
            else
                return [children[1:matchidx]..., child, children[matchidx+1:end]...], true
            end
        end
    end |> first
end


function Base.filter(sel::Selector, doc::XExpr)
    return foldchildren(doc, nothing) do children, _
        return [child for child in children if matches(sel, child)], nothing
    end |> first
end
