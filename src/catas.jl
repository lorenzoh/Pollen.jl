# Filtered catamorphisms


function cata(f, xtree, selector::Selector)
    return cata(xtree) do x
        matches(selector, x) ? f(x) : x
end
end


function catafirst(f, xtree, selector::Selector)
    xtree_, state_ = catafold(xtree, false) do x, done
        (!done && matches(selector, x)) ? (f(x), true) : (x, done)
    end
    return xtree_
end


# Replace

function replace(xtree, xnode, selector::Selector)
    cata(x -> xnode, xtree, selector)
end


function replacefirst(xtree, xnode, selector::Selector)
    return catafirst(x -> xnode, xtree, selector)
end


function replacemany(xtree, xnodes, selector::Selector)
    xtree_, state_ = catafold(xtree, 1) do x, i
        matches(selector, x) ? (xnodes[i], i + 1) : (x, i)
    end
    return xtree_
end


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


_insert(xs::AbstractVector{T}, i, x::T) where T = insert!(copy(xs), i, x)
_insert(xs::AbstractVector{<:XTree}, i, x::XTree) = vcat(xs[1:i - 1], [x], xs[i:end])
