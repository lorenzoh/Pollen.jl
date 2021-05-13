struct Markdown <: Format end


function parse(io::IO, ::Markdown; parser = default_md_parser())
    ast = parser(io)
    return convert(XTree, ast)
end

function default_md_parser()
    # adapted from https://github.com/MichaelHatherly/Publish.jl/blob/master/src/utilities.jl
    cm = CommonMark
    parser = cm.enable!(cm.Parser(), [
        ## CommonMark-provided.
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

extensionformat(::Val{:md}) = Markdown()
formatextension(::Markdown) = "md"

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

function mdchildrenattrs(node::CommonMark.Node)
    allcs = mdchildren(node)
    cs = CommonMark.Node[]
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


function childrenxtrees(node::Node)
    cs, attrs = mdchildrenattrs(node)
    return XTree[convert(XTree, c, as) for (c, as) in zip(cs, attrs)]
end

Base.convert(::Type{XTree}, node::Node, attrs::Dict = Dict{Symbol, Any}()) = convert(XTree, node, node.t, attrs)

const BLOCK_TO_TAG = Dict(
    Document => :body,
    Item => :li,
    List => :ul,
    Paragraph => :p,
    Text => :span,
    Emph => :em,
    SoftBreak => :br,
    ThematicBreak => :hr,
    BlockQuote => :blockquote,
    Admonition => :admonition,
    Citation => :citation,
    CommonMark.Strong => :strong,
    CommonMark.Table => :table,
    CommonMark.TableHeader => :span,
    CommonMark.TableRow => :tr,
    CommonMark.TableCell => :td,
    CommonMark.TableBody => :div,
    CommonMark.FrontMatter => :fm,
)

function Base.convert(::Type{XTree}, node::Node, c::AbstractContainer, attrs = Dict{Symbol, String}())
    tag = BLOCK_TO_TAG[typeof(c)]
    # TODO: respect `Attributes`
    return XNode(tag, attrs, childrenxtrees(node))
end


# For some `AbstractContainer`s, the behavior is customized.


Base.convert(::Type{XTree}, node::Node, ::Text, attrs) = XLeaf(node.literal)
Base.convert(::Type{XTree}, node::Node, ::Code, attrs) = XNode(:code, [XLeaf(node.literal)])

function Base.convert(::Type{XTree}, node::Node, i::Image, attrs) XNode(:code, [XLeaf(node.literal)])
    return XNode(
        :img,
        Dict(:src => i.destination, :alt => i.title),
        childrenxtrees(node)
    )
end

function Base.convert(::Type{XTree}, node::Node, c::CodeBlock, attrs)
    return XNode(
        :pre,
        merge(attrs, Dict(:lang => c.info)),
        [XNode(:code, [XLeaf(node.literal)])],)
end

function Base.convert(::Type{XTree}, node::Node, l::Link, attrs)
    return XNode(
        :a,
        Dict(:href => l.destination, :title => l.title),
        childrenxtrees(node))
end

function Base.convert(::Type{XTree}, node::Node, c::Heading, attrs)
    tag = Symbol("h$(c.level)")
    return XNode(tag, attrs, childrenxtrees(node))
end


# TODO: add conversion for Table Nodes
