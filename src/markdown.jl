struct Markdown <: Format end


function parse(io::IO, ::Markdown; parser = CommonMark.Parser())
    ast = parser(io)
    return xexpr(ast)
end

extensionformat(::Val{:md}) = Markdown()

## Parsing helpers

function mdchildren(node::CommonMark.Node)
    if !isdefined(node.first_child, :t)
        return CommonMark.Node[]
    end

    child = node.first_child
    childs = [child]

    while child != node.last_child
        child = child.nxt
        push!(childs, child)
    end
    return childs
end

xexpr(node::Node) = xexpr(node, node.t)

# Default behavior is to wrap the contents in a tag.

const BLOCK_TO_TAG = Dict(
    Document => :body,
    Item => :li,
    List => :ul,
    Paragraph => :p,
    Text => :span,
    Emph => :em,
    SoftBreak => :br,
    ThematicBreak => :hr,
)

function xexpr(ast::Node, c::AbstractContainer)
    tag = BLOCK_TO_TAG[typeof(c)]
    # TODO: respect `Attributes`
    return xexpr(tag, mdchildren(ast)...)
end


# For some `AbstractContainer`s, the behavior is customized.

xexpr(node::Node, ::Text) = node.literal
xexpr(node::Node, ::Code) = xexpr(:code, node.literal)
xexpr(node::Node, c::CodeBlock) = xexpr(:pre, Dict(:lang => c.info), (:code, node.literal))
function xexpr(node::Node, l::Link)
    xexpr(:a, Dict(:href => l.destination, :title => l.title), mdchildren(node)...)
end
function xexpr(node::Node, c::Heading)
    tag = Symbol("h$(c.level)")
    return xexpr(tag, node.first_child.literal)
end
