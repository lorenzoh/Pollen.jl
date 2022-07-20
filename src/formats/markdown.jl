"""
    MarkdownFormat([parser]) <: Format

Format for reading CommonMark-compliant Markdown. See
[CommonMark.jl](https://github.com/MichaelHatherly/CommonMark.jl)
for a reference.
"""
struct MarkdownFormat <: Format
    parser::CM.Parser
    concatstrings::Bool
end
function MarkdownFormat(parser = default_md_parser(); concatstrings = true)
    MarkdownFormat(default_md_parser(), concatstrings)
end

function parse(io::IO, format::MarkdownFormat)
    ast = format.parser(io)
    #if format.concatstrings

    #end
    return xtree(ast)
end

function default_md_parser()
    # adapted from https://github.com/MichaelHatherly/Publish.jl/blob/master/src/utilities.jl
    cm = CM
    parser = cm.enable!(cm.Parser(),
                        [
                            ## CM-provided.
                            cm.AdmonitionRule(),
                            cm.AttributeRule(),
                            cm.AutoIdentifierRule(),
                            cm.CitationRule(),
                            cm.DollarMathRule(),
                            cm.FootnoteRule(),
                            cm.FrontMatterRule(toml = TOML.parse),
                            cm.MathRule(),
                            cm.RawContentRule(),
                            cm.TableRule(),
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
    return combine(childs, c -> c.t isa CM.Text) do cs
        textnode(string(getfield.(cs, :literal)...))
    end
end

function textnode(str)
    node = CM.Node(CM.Text())
    node.literal = str
    return node
end

function combine(f, v::AbstractVector, predicate)
    buf = []
    res = []

    for x in v
        if predicate(x)
            push!(buf, x)
        else
            if !isempty(buf)
                push!(res, f(buf))
                buf = []
            end
            push!(res, x)
        end
    end
    if !isempty(buf)
        push!(res, f(buf))
        buf = []
    end
    return res
end

function mdchildrenattrs(node::CM.Node)
    allcs = mdchildren(node)
    cs = CM.Node[]
    attrs = Dict{Symbol, String}[]
    as = Dict{Symbol, String}()

    for c in allcs
        if c.t isa CM.Attributes
            as = Dict{Symbol, Any}((Symbol(k), v) for (k, v) in c.t.dict)
            if haskey(as, :class)
                as[:class] = join(as[:class], ';')
            end
        else
            # Inline attributes come after the token
            if c.t isa CM.AbstractInline
                push!(cs, c)
                if !isempty(as)
                    attrs[end] = merge(attrs[end], as)
                end
                push!(attrs, Dict{Symbol, String}())
                # While block attributes come before the token
            else
                push!(cs, c)
                push!(attrs, as)
            end
            as = Dict{Symbol, String}()
        end
    end
    return cs, attrs
end

function childrenxtrees(node::CM.Node)
    cs, attrs = mdchildrenattrs(node)
    return XTree[xtree(c, as) for (c, as) in zip(cs, attrs)]
end

xtree(node::CM.Node, attrs::Dict = Dict{Symbol, Any}()) = xtree(node, node.t, attrs)

const BLOCK_TO_TAG = Dict(CM.Item => :li,
                          CM.Paragraph => :p,
                          CM.Text => :span,
                          CM.Emph => :em,
                          CM.LineBreak => :br,
                          CM.ThematicBreak => :hr,
                          CM.BlockQuote => :blockquote,
                          CM.Admonition => :admonition,
                          CM.Citation => :citation,
                          CM.Strong => :strong,
                          CM.Table => :table,
                          CM.TableRow => :tr,
                          CM.TableCell => :td,
                          CM.FrontMatter => :fm,
                          CM.HtmlInline => :span,
                          CM.FootnoteLink => :footnotelink,
                          CM.FootnoteDefinition => :footnotedef,
                          CM.Backslash => :backslash)

function xtree(node::CM.Node, c::CM.AbstractContainer, attrs = Dict{Symbol, String}())
    tag = BLOCK_TO_TAG[typeof(c)]
    return Node(tag, childrenxtrees(node), attrs)
end

# For some `AbstractContainer`s, the behavior is customized.

xtree(node::CM.Node, ::CM.Text, attrs) = Leaf(node.literal)
xtree(::CM.Node, ::CM.SoftBreak, attrs) = Leaf(" ")
xtree(node::CM.Node, ::CM.Code, attrs) = Node(:code, [Leaf(node.literal)], attrs)
xtree(node::CM.Node, ::CM.Math, attrs) = Node(:math, [Leaf(node.literal)], attrs)
function xtree(node::CM.Node, ::CM.DisplayMath, attrs)
    Node(:mathblock, [Leaf(node.literal)], attrs)
end

function xtree(node::CM.Node, ::CM.HtmlBlock, attrs)
    withattributes(parse(node.literal, HTMLFormat()), attrs)
end

function xtree(node::CM.Node, ::CM.Paragraph, attrs)
    chs = XTree[]
    s = ""
    for ch in childrenxtrees(node)
        if ch isa Leaf{String}
            s *= ch[]
        else
            if !isempty(s)
                push!(chs, Leaf(s))
                s = ""
            end
            push!(chs, ch)
        end
    end
    if !isempty(s)
        push!(chs, Leaf(s))
    end
    return Node(:p, chs, attrs)
end

function xtree(node::CM.Node, ::CM.Document, attrs)
    attrs = frontmatter(node)
    if !isempty(attrs)
        node.first_child = node.first_child.nxt
    end

    return Node(:md,
                childrenxtrees(node),
                attrs)
end

function frontmatter(cmnode::CM.Node)
    Dict{Symbol, Any}(Symbol(k) => v for (k, v) in CM.frontmatter(cmnode))
end

function xtree(node::CM.Node, i::CM.Image, attrs)
    return Node(:img,
                childrenxtrees(node),
                Dict(:src => i.destination, :alt => i.title))
end

function xtree(node::CM.Node, c::CM.CodeBlock, attrs)
    return Node(:codeblock,
                node.literal;
                attrs..., lang = c.info)
end

function xtree(node::CM.Node, c::CM.List, attrs)
    tag = c.list_data.type == :ordered ? :ol : :ul
    return Node(tag, childrenxtrees(node))
end

function xtree(node::CM.Node, l::CM.Link, attrs)
    return Node(:a,
                childrenxtrees(node),
                Dict(:href => l.destination, :title => l.title))
end

function xtree(node::CM.Node, c::CM.Heading, attrs)
    tag = Symbol("h$(c.level)")
    return Node(tag, childrenxtrees(node), attrs)
end

function xtree(node::CM.Node, c::CM.Admonition, attrs)
    return Node(:admonition,
                [
                    Node(:admonitiontitle, [Leaf(c.title)]),
                    Node(:admonitionbody, childrenxtrees(node)),
                ], Dict(:class => c.category))
end

# tables

function xtree(cmnode::CM.Node, ::CM.TableHeader, attrs)
    node = Node(:tr, childrenxtrees(cmnode.first_child), attrs)
    return cata(node -> withtag(node, :th), node, SelectTag(:td))
end

function xtree(cmnode::CM.Node, c::CM.Table, attrs)
    nodeheader = cmnode.first_child
    nodebody = nodeheader.nxt

    return Node(:table,
                [
                    xtree(nodeheader),
                    childrenxtrees(nodebody)...,
                ],
                merge(attrs, Dict(:align => c.spec)))

    node = Node(:tr, childrenxtrees(cmnode), attrs)
    return cata(node -> withtag(node, :th), node, SelectTag(:td))
end

@testset "MarkdownFormat" begin
    f = MarkdownFormat()

    @testset "Inline" begin
        # ## Inline styles
        @test parse("Hi", f) == Node(:md, Node(:p, "Hi"))
        # emphasis
        @test parse("_Hi_", f) == Node(:md, Node(:p, Node(:em, "Hi")))
        @test parse("**Hi**", f) == Node(:md, Node(:p, Node(:strong, "Hi")))
        # code
        @test parse("`code`", f) == Node(:md, Node(:p, Node(:code, "code")))

        @testset "Math (inline)" begin
            @test parse("``x^2 = y``", f) == Node(:md, Node(:p, Node(:math, "x^2 = y")))
            @test parse("``x^2 = y``", f) == parse("\$x^2 = y\$", f)
        end
    end

    @testset "Blocks" begin
        # Lists
        @test parse("- Hi", f) == Node(:md, Node(:ul, Node(:li, Node(:p, "Hi"))))
        @test parse("1. Hi", f) == Node(:md, Node(:ol, Node(:li, Node(:p, "Hi"))))

        # Breaks
        @test Pollen.parse("Hi\n\n---\n", f) == Node(:md, Node(:p, "Hi"), Node(:hr))

        # Code blocks
        cb = Pollen.parse("""
        ```julia
        f(x) = 1
        ```
        """, f)
        @test cb == Node(:md, Node(:codeblock, "f(x) = 1\n", lang = "julia"))

        # Block quotes
        @test Pollen.parse("> Hi", f) == Node(:md, Node(:blockquote, Node(:p, "Hi")))

        @testset "FrontMatter" begin @test Pollen.parse("+++\nx = \"y\"\n+++\n\nhi\n", f) ==
                                           Node(:md,
                                                Node(:p, "hi");
                                                x = "y") end

        @testset "HtmlBlock" begin @test parse("<div>hi</div>", f) ==
                                         Node(:md, Node(:html, Node(:div, "hi"))) end

        @testset "Tables" begin
            s = """
            | x | y |
            |:--|--:|
            |hello|world|
            """
            @test Pollen.parse(s, f) == Node(:md,
                       Node(:table,
                            Node(:tr, Node(:th, "x"), Node(:th, "y")),
                            Node(:tr, Node(:td, "hello"), Node(:td, "world"));
                            align = [:left, :right]))
        end

        @testset "Admonitions" begin
            s = """
            !!! note "Title"

                Hello world
            """
            @test Pollen.parse(s, f) == Node(:md,
                       Node(:admonition,
                            Node(:admonitiontitle, "Title"),
                            Node(:admonitionbody, Node(:p, "Hello world")),
                            class = "note"))
        end

        @testset "Math (block)" begin @test Pollen.parse("""
                                          \$\$
                                          f(x) = y
                                          \$\$
                                          """, f) == Node(:md, Node(:mathblock, "f(x) = y")) end
    end

    @testset "Attributes" begin
        @testset "Block-level" begin
            node = Pollen.parse("""
                {.hello #world attr=hi}
                Hello
                """, f)
            @test node == Node(:md,
                       Node(:p, "Hello";
                            id = "world", class = "hello", attr = "hi"))
        end

        @testset "Inline" begin
            node = Pollen.parse("Hello `code`{attr=hi} world", f)
            @test node == Node(:md, Node(:p,
                                 "Hello ",
                                 Node(:code, "code"; attr = "hi"),
                                 " world"))
        end
    end
end
