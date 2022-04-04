struct MarkdownFormat <: Format end


function parse(io::IO, ::MarkdownFormat; parser = default_md_parser())
    ast = parser(io)
    return convert(XTree, ast)
end

function default_md_parser()
    # adapted from https://github.com/MichaelHatherly/Publish.jl/blob/master/src/utilities.jl
    cm = CM
    parser = cm.enable!(cm.Parser(), [
        ## CM-provided.
        cm.AdmonitionRule(),
        cm.AttributeRule(),
        cm.AutoIdentifierRule(),
        cm.CitationRule(),
        cm.DollarMathRule(),
        cm.FootnoteRule(),
        cm.FrontMatterRule(toml=TOML.parse),
        cm.MathRule(),
        cm.RawContentRule(),
        cm.TableRule(),
        cm.TypographyRule(),
    ])
    return parser
end

extensionformat(::Val{:md}) = MarkdownFormat()
formatextension(::MarkdownFormat) = "md"

## Parsing helpers

function mdchildren(node::CM.Node)
    if !isdefined(node.first_child, :t)
        return CM.Node[]
    end

    child = node.first_child
    childs = [child]

    while child != node.last_child
        child = child.nxt
        push!(childs, child)
    end
    return childs
end

function mdchildrenattrs(node::CM.Node)
    allcs = mdchildren(node)
    cs = CM.Node[]
    attrs = Dict{Symbol, String}[]
    as = Dict{Symbol, String}()

    for (i, c) in enumerate(allcs)
        if c.t isa Attributes
            as = Dict{Symbol, Any}((Symbol(k), v) for (k, v) in c.t.dict)
            if haskey(as, :class)
                as[:class] = join(as[:class], ';')
            end
        else
            push!(cs, c)
            push!(attrs, as)
            as = Dict{Symbol, String}()
        end
    end
    return cs, attrs
end


function childrenxtrees(node::CM.Node)
    cs, attrs = mdchildrenattrs(node)
    return XTree[convert(XTree, c, as) for (c, as) in zip(cs, attrs)]
end

Base.convert(::Type{XTree}, node::CM.Node, attrs::Dict = Dict{Symbol, Any}()) = convert(XTree, node, node.t, attrs)

const BLOCK_TO_TAG = Dict(
    CM.Document => :body,
    CM.Item => :li,
    CM.List => :ul,
    CM.Paragraph => :p,
    CM.Text => :span,
    CM.Emph => :em,
    CM.SoftBreak => :br,
    CM.ThematicBreak => :hr,
    CM.BlockQuote => :blockquote,
    CM.Admonition => :admonition,
    Citation => :citation,
    CM.Strong => :strong,
    CM.Table => :table,
    CM.TableHeader => :span,
    CM.TableRow => :tr,
    CM.TableCell => :td,
    CM.TableBody => :div,
    CM.FrontMatter => :fm,
)

function Base.convert(::Type{XTree}, node::Node, c::CM.AbstractContainer, attrs = Dict{Symbol, String}())
    tag = BLOCK_TO_TAG[typeof(c)]
    # TODO: respect `Attributes`
    return Node(tag, attrs, childrenxtrees(node))
end


# For some `AbstractContainer`s, the behavior is customized.


Base.convert(::Type{XTree}, node::CM.Node, ::CM.Text, attrs) = Leaf(node.literal)
Base.convert(::Type{XTree}, node::CM.Node, ::CM.Code, attrs) = Node(:code, [Leaf(node.literal)])

function Base.convert(::Type{XTree}, node::CM.Node, i::CM.Image, attrs) Node(:code, [Leaf(node.literal)])
    return Node(
        :img,
        Dict(:src => i.destination, :alt => i.title),
        childrenxtrees(node)
    )
end

function Base.convert(::Type{XTree}, node::CM.Node, c::CM.CodeBlock, attrs)
    return Node(
        :pre,
        merge(attrs, Dict(:lang => c.info)),
        [Node(:code, [Leaf(node.literal)])],)
end

function Base.convert(::Type{XTree}, node::CM.Node, l::CM.Link, attrs)
    return Node(
        :a,
        Dict(:href => l.destination, :title => l.title),
        childrenxtrees(node))
end

function Base.convert(::Type{XTree}, node::CM.Node, c::CM.Heading, attrs)
    tag = Symbol("h$(c.level)")
    return Node(tag, attrs, childrenxtrees(node))
end


function Base.convert(::Type{XTree}, node::Node, c::Admonition, attrs)
    return XNode(:admonition, Dict(:class => c.category), [
        XNode(:admonitiontitle, [XLeaf(c.title)]),
        XNode(:admonitionbody, childrenxtrees(node))
    ])
end


# TODO: add conversion for Table Nodes
