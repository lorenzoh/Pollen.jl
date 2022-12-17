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
    parser = cm.enable!(
        cm.Parser(),
        [
            ## CM-provided.
            cm.AdmonitionRule(),
            cm.AttributeRule(),
            cm.AutoIdentifierRule(),
            cm.CitationRule(),
            cm.DollarMathRule(),
            cm.FootnoteRule(),
            cm.FrontMatterRule(
                toml = TOML.parse,
                json = Dict ∘ JSON3.read,
                yaml = YAML.load,
            ),
            cm.MathRule(),
            cm.RawContentRule(),
            cm.TableRule(),
        ],
    )
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
    attrs = Dict{Symbol,String}[]
    as = Dict{Symbol,String}()

    for (i, c) in enumerate(allcs)
        if c.t isa CM.Attributes
            as = Dict{Symbol,Any}((Symbol(k), v) for (k, v) in c.t.dict)
            if haskey(as, :class)
                as[:class] = join(as[:class], ';')
            end
            # last child
            if i == length(allcs) && allcs[end-1].t isa CM.AbstractInline
                attrs[end] = merge(attrs[end], as)
                as = Dict{Symbol,String}()
            end
        else
            # Inline attributes come after the token
            if c.t isa CM.AbstractInline
                push!(cs, c)
                if !isempty(as)
                    attrs[end] = merge(attrs[end], as)
                end
                push!(attrs, Dict{Symbol,String}())
                # While block attributes come before the token
            else
                push!(cs, c)
                push!(attrs, as)
            end
            as = Dict{Symbol,String}()
        end
    end
    return cs, attrs
end

function childrenxtrees(node::CM.Node)
    cs, attrs = mdchildrenattrs(node)
    return XTree[xtree(c, as) for (c, as) in zip(cs, attrs)]
end

xtree(node::CM.Node, attrs::Dict = Dict{Symbol,Any}()) = xtree(node, node.t, attrs)

const BLOCK_TO_TAG = Dict(
    CM.Item => :li,
    CM.Paragraph => :p,
    CM.Text => :span,
    CM.Emph => :em,
    CM.LineBreak => :br,
    CM.ThematicBreak => :hr,
    CM.BlockQuote => :blockquote,
    CM.Admonition => :admonition,
    CM.Strong => :strong,
    CM.Table => :table,
    CM.TableRow => :tr,
    CM.TableCell => :td,
    CM.FrontMatter => :fm,
    CM.HtmlInline => :span,
    CM.FootnoteLink => :footnotelink,
    CM.FootnoteDefinition => :footnotedef,
    CM.Backslash => :backslash,
)

function xtree(node::CM.Node, c::CM.AbstractContainer, attrs = Dict{Symbol,String}())
    tag = BLOCK_TO_TAG[typeof(c)]
    return Node(tag, childrenxtrees(node), attrs)
end

# For some `AbstractContainer`s, the behavior is customized.

_maybespan(x, attrs) = isempty(attrs) ? x : Node(:span, [x], attrs)
xtree(node::CM.Node, ::CM.Text, attrs) = _maybespan(Leaf(node.literal), attrs)
xtree(::CM.Node, ::CM.SoftBreak, attrs) = _maybespan(Leaf(" "), attrs)
xtree(node::CM.Node, ::CM.Code, attrs) = Node(:code, [Leaf(node.literal)], attrs)
xtree(node::CM.Node, ::CM.Math, attrs) = Node(:math, [Leaf(node.literal)], attrs)
function xtree(node::CM.Node, t::CM.Citation, attrs)
    Node(:citation, Leaf[], merge(attrs, Dict(:id => t.id)))
end
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

    return Node(:md, childrenxtrees(node), attrs)
end

function frontmatter(cmnode::CM.Node)
    Dict{Symbol,Any}(Symbol(k) => v for (k, v) in CM.frontmatter(cmnode))
end

function xtree(node::CM.Node, i::CM.Image, attrs)
    return Node(
        :img,
        childrenxtrees(node),
        merge(attrs, Dict(:src => i.destination, :alt => i.title)),
    )
end

function xtree(node::CM.Node, c::CM.CodeBlock, attrs)
    return Node(
        tag = :codeblock,
        children = [Leaf(node.literal)];
        attributes = merge(attrs, Dict(:lang => c.info)),
    )
end

function xtree(node::CM.Node, c::CM.List, attrs)
    tag = c.list_data.type == :ordered ? :ol : :ul
    return Node(tag, childrenxtrees(node), attrs)
end

function xtree(node::CM.Node, l::CM.Link, attrs)
    return Node(
        :a,
        childrenxtrees(node),
        merge(attrs, Dict(:href => l.destination, :title => l.title)),
    )
end

function xtree(node::CM.Node, c::CM.Heading, attrs)
    tag = Symbol("h$(c.level)")
    return Node(tag, childrenxtrees(node), attrs)
end

function xtree(node::CM.Node, c::CM.Admonition, attrs)
    return Node(
        tag = :admonition,
        children = [
            Node(:admonitiontitle, [Leaf(c.title)]),
            Node(:admonitionbody, childrenxtrees(node)),
        ],
        attributes = merge(attrs, Dict(:class => c.category)),
    )
end

# tables

function xtree(cmnode::CM.Node, ::CM.TableHeader, attrs)
    node = Node(:tr, childrenxtrees(cmnode.first_child), attrs)
    return cata(node -> withtag(node, :th), node, SelectTag(:td))
end

function xtree(cmnode::CM.Node, c::CM.Table, attrs)
    nodeheader = cmnode.first_child
    nodebody = nodeheader.nxt

    return Node(
        :table,
        [xtree(nodeheader), childrenxtrees(nodebody)...],
        merge(attrs, Dict(:align => c.spec)),
    )

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
        cb = Pollen.parse(
            """
```julia
f(x) = 1
```
""",
            f,
        )
        @test cb == Node(:md, Node(:codeblock, "f(x) = 1\n", lang = "julia"))

        # Block quotes
        @test Pollen.parse("> Hi", f) == Node(:md, Node(:blockquote, Node(:p, "Hi")))

        @testset "FrontMatter" begin
            @test Pollen.parse("+++\nx = \"y\"\n+++\n\nhi\n", f) ==
                  Node(:md, Node(:p, "hi"); x = "y")
        end

        @testset "HtmlBlock" begin
            @test parse("<div>hi</div>", f) == Node(:md, Node(:html, Node(:div, "hi")))
        end

        @testset "Tables" begin
            s = """
            | x | y |
            |:--|--:|
            |hello|world|
            """
            @test Pollen.parse(s, f) == Node(
                :md,
                Node(
                    :table,
                    Node(:tr, Node(:th, "x"), Node(:th, "y")),
                    Node(:tr, Node(:td, "hello"), Node(:td, "world"));
                    align = [:left, :right],
                ),
            )
        end

        @testset "Admonitions" begin
            s = """
            !!! note "Title"

                Hello world
            """
            @test Pollen.parse(s, f) == Node(
                :md,
                Node(
                    :admonition,
                    Node(:admonitiontitle, "Title"),
                    Node(:admonitionbody, Node(:p, "Hello world")),
                    class = "note",
                ),
            )
        end

        @testset "Citation" begin
            @test Pollen.parse("@cit", f) == Node(:md, Node(:p, Node(:citation, id = "cit")))
        end

        @testset "Math (block)" begin
            @test Pollen.parse(
                """
 \$\$
 f(x) = y
 \$\$
 """,
                f,
            ) == Node(:md, Node(:mathblock, "f(x) = y"))
        end
    end

    @testset "Attributes" begin
        @testset "Block-level" begin
            node = Pollen.parse(
                """
{.hello #world attr=hi}
Hello
""",
                f,
            )
            @test node ==
                  Node(:md, Node(:p, "Hello"; id = "world", class = "hello", attr = "hi"))
        end

        @testset "Inline" begin
            node = Pollen.parse("Hello `code`{attr=hi} world", f)
            @test node ==
                  Node(:md, Node(:p, "Hello ", Node(:code, "code"; attr = "hi"), " world"))
        end
    end

    @testset "FrontMatter" begin
        s = """---\nx: y\n---\nhi\n"""
        @test attributes(parse(s, f)) == Dict(:x => "y")
        s = """+++\nx = "y"\n+++\nhi\n"""
        @test attributes(parse(s, f)) == Dict(:x => "y")
        s = """;;;\n{"x":"y"}\n;;;\nhi\n"""
        @test_broken attributes(parse(s, f)) == Dict(:x => "y")
    end
end


function render!(io::IO, doc::Node, ::MarkdownFormat)
    ast = to_commonmark_ast(doc)
    CM.markdown(io, ast)
end

function to_commonmark_ast(node::Node)
    to_commonmark_ast(node, Val(node.tag))
end

function to_commonmark_ast(node, ::Val{X}) where X
    @warn "Cannot render Node with tag `$X` to Markdown."
    to_commonmark_ast(Node(:p, Leaf("Node type $X not implemented.")))
end

function to_commonmark_ast(str::Leaf)
    n = CM.Node(CM.Text())
    n.literal = repr(MIME"text/plain"(), str[])
    return n
end

function to_commonmark_ast(str::Leaf{<:AbstractString})
    n = CM.Node(CM.Text())
    n.literal = String(str[])
    return n
end

function to_commonmark_ast(node, ::Union{Val{:document},Val{:md}})
    ast = CM.Node(CM.Document())
    if !isempty(attributes(node))
        fm = CM.FrontMatter("---")
        for k in keys(attributes(node))
            fm.data[string(k)] = attributes(node)[k]
        end
        fmnode = CM.Node(fm)
        fmnode.literal = YAML.write(attributes(node))
        CM.append_child(ast, fmnode)
    end
    append_ast_children!(ast, node)
    ast
end

function to_commonmark_ast(node, ::Val{:p})
    n = CM.Node(CM.Paragraph())
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:a})
    l = CM.Link()
    l.destination = node.attributes[:href]
    n = CM.Node(l)

    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:strong})
    t = CM.Strong()
    n = CM.Node(t)
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:html})
    t = CM.HtmlBlock()
    t.html_block_type = 6
    n = CM.Node(t)
    buf = IOBuffer()
    foreach(children(node)) do ch
        render!(buf, ch, HTMLFormat())
    end
    n.literal = String(take!(buf))
    return n
    #append_ast_children!(n, node)
end


function to_commonmark_ast(node, ::Val{:citation})
    return CM.Node(CM.Citation(attributes(node)[:id], false))
end

function to_commonmark_ast(
    node,
    V::Union{
        Val{:h1},
        Val{:h2},
        Val{:h3},
        Val{:h4},
        Val{:h5},
        Val{:h6},
        Val{:h7},
        Val{:h8},
        Val{:h9},
    },
)
    _level(v::Val{X}) where {X} = Base.parse(Int, string(X)[2:end])
    h = CM.Heading()
    h.level = _level(V)
    n = CM.Node(h)
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:img})
    n = CM.Node(CM.Paragraph())
    img = CM.Image()
    img.destination = node.attributes[:src]
    n2 = CM.Node(img)
    CM.append_child(n, n2)
    append_ast_children!(n2, node)
    n
end

function to_commonmark_ast(node, ::Val{:codecell})
    map(to_commonmark_ast, children(node))
end

function to_commonmark_ast(node, ::Val{:codeinput})
    cb = CM.CodeBlock()
    cb.is_fenced = true
    cb.fence_char = '`'
    cb.fence_length = 3
    cb.info = attributes(node)[:lang]
    n = CM.Node(cb)
    n.literal = gettext(node)
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:codeblock})
    cb = CM.CodeBlock()
    cb.is_fenced = true
    cb.fence_char = '`'
    cb.fence_length = 3
    cb.info = attributes(node)[:lang]
    n = CM.Node(cb)
    n.literal = gettext(node)
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:code})
    cb = CM.Code()
    n = CM.Node(cb)
    n.literal = gettext(node)
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:em})
    n = CM.Node(CM.Emph())
    n.literal = "_"
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:ul})
    n = CM.Node(CM.List())
    ld = CM.ListData()
    ld.padding = 2
    ld.bullet_char = '-'
    n.t.list_data = ld
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:li})
    n = CM.Node(CM.Item())
    ld = CM.ListData()
    ld.padding = 2
    ld.bullet_char = '-'
    n.t.list_data = ld
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:coderesult})
    cb = CM.CodeBlock()
    cb.is_fenced = true
    cb.fence_char = '`'
    cb.fence_length = 3
    n = CM.Node(cb)
    n.literal = repr(only(children(only(children(node))))[]) * '\n'
    display(node)
    n
end

function append_ast_children!(commonmarknode, pollennode)
    for c in children(pollennode)
        cn = to_commonmark_ast(c)
        if cn !== nothing
            if cn isa AbstractArray
                for _cn in cn
                    # expand a vector of nodes
                    CM.append_child(commonmarknode, _cn)
                end
            else
                CM.append_child(commonmarknode, cn)
            end
        end
    end
    return commonmarknode
end
