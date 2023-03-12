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

as_md(node::Node) = default_md_parser()(render(node, MarkdownFormat()))

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
    CM.CitationBracket => :citationbracket,
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
        [
            Node(:tableheader, xtree(nodeheader)),
            Node(:tablebody, childrenxtrees(nodebody)...),
        ],
        merge(attrs, Dict(:align => c.spec)),
    )
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
                    Node(:tableheader, Node(:tr, Node(:th, "x"), Node(:th, "y"))),
                    Node(:tablebody, Node(:tr, Node(:td, "hello"), Node(:td, "world")));
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
    ast = try
        to_commonmark_ast(doc)
    catch
        @error "Error while converting `Node` to Markdown AST" node=doc
        rethrow()
    end
    CM.markdown(io, ast)
end

function render!(io::IO, leaf::Leaf{<:AbstractString}, ::MarkdownFormat)
    CM.markdown(io, CM.text(leaf[]))
end

function to_commonmark_ast(node::Node)
    to_commonmark_ast(node, Val(node.tag))
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


const TAG_TO_AST_TYPE = Dict(
    :document => :doc,
    :md => :doc,
    :documentation => :doc,
    :jl => :block,
    :docstring => :block,
    :sourcefile => :doc,
    :div => :block,
    :docsblock => :block,
)


# This is the fallback method
function to_commonmark_ast(node, ::Val{S}) where S
    ast_type = get(TAG_TO_AST_TYPE, S, nothing)
    if isnothing(ast_type)
        @warn "Cannot render node with tag `$S` to Markdown" node
        return to_commonmark_ast(Leaf("Cannot render tag $S"))
    end
    if ast_type === :doc
        return to_commonmark_ast_document(node)
    elseif ast_type === :block
        return to_commonmark_ast_block(node)
    else
        error("Invalid AST type $ast_type")
    end
end

function to_commonmark_ast_document(node)
    ast = CM.Node(CM.Paragraph())
    add_frontmatter!(ast, attributes(node))
    append_ast_children!(ast, node)
    ast
end

function to_commonmark_ast_block(node)
    ast = CM.Node(CM.Paragraph())
    add_frontmatter!(ast, attributes(node))
    append_ast_children!(ast, node)
    ast
end


function add_frontmatter!(ast, attrs::Dict)
    if !isempty(attrs)
        fm = CM.FrontMatter("---")
        for k in keys(attrs)
            fm.data[string(k)] = attrs[k]
        end
        fmnode = CM.Node(fm)
        fmnode.literal = YAML.write(attrs)
        CM.append_child(ast, fmnode)
    end
end

function to_commonmark_ast(node, ::Val{:p})
    n = CM.Node(CM.Paragraph())
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:hr})
    n = CM.Node(CM.ThematicBreak())
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:math})
    inner = render(only(children(node)), MarkdownFormat())
    return CM.text("\$$inner\$")
end

function to_commonmark_ast(node, ::Val{:mathblock})
    inner = render(only(children(node)), MarkdownFormat())
    return CM.text("\$\$\n$inner\n\$\$")
end

function to_commonmark_ast(node, ::Val{:displaymath})
    n = CM.Node(CM.DisplayMath())
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:a})
    l = CM.Link()
    l.destination = attributes(node)[:href]
    n = CM.Node(l)

    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:reference})
    href = buildpath("/", attributes(node)[:document_id], MarkdownFormat())
    return to_commonmark_ast(
        Node(:a, children(node), merge(
                attributes(node),
                Dict(:href => href))), Val(:a))
end


function to_commonmark_ast(node, ::Val{:strong})
    t = CM.Strong()
    n = CM.Node(t)
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:admonition})
    category = get(attributes(node), :class, "")
    title = only(children(children(node)[1]))[]
    t = CM.Admonition(category, title)
    n = CM.Node(t)
    append_ast_children!(n, children(node)[2])
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
end

function to_commonmark_ast(node, ::Val{:julia})
    node = htmlify(node)
    to_commonmark_ast(Node(:html, node))
end

function htmlify(node::Node)
    cata(node, SelectNode()) do ch
        attrs = attributes(ch)
        if tag(ch) == :julia
            _as_html_elem(ch, :div)
        elseif tag(ch) == :codeblock
            Node(:pre, [Node(:code, children(ch))], attrs)
        elseif !(tag(ch) in HTMLFormatTAGS)
            _as_html_elem(ch, :span)
        else
           return ch
        end
    end
end

function _as_html_elem(node::Node, elem::Symbol)
    attrs = attributes(node)
    Node(elem, children(node),
         merge(attrs, Dict(:class => get(attrs, :class, "") * string(tag(node)))))
end

function to_commonmark_ast(node, ::Val{:citation})
    bracket_open = CM.Node(CM.CitationBracket())
    bracket_open.literal = "["
    bracket_close = CM.Node(CM.CitationBracket())
    bracket_close.literal = "]"
    return [
        bracket_open,
        CM.Node(CM.Citation(attributes(node)[:id], true)),
        bracket_close,
    ]
end

to_commonmark_ast(node, ::Val{:citationbracket}) = []

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
    return to_commonmark_ast(Node(:html, node))
    codeattrs, outputattrs, resultattrs = __parsecodeattributes(attributes(node))
    ch = Any[
        to_commonmark_ast(Node(:codeblock, children(node), codeattrs)),
    ]
    if !isnothing(outputattrs[:value]) && get(outputattrs, :show, "true") == "true"
        push!(ch, to_commonmark_ast(Leaf(outputattrs[:value])))
    end
    if !isnothing(resultattrs[:value]) && get(resultattrs, :show, "true") == "true"
        push!(ch, to_commonmark_ast(Leaf(resultattrs[:value])))
    end
    return ch
end

function to_commonmark_ast(node, ::Val{:codeinput})
    cb = CM.CodeBlock()
    cb.is_fenced = true
    cb.fence_char = '`'
    cb.fence_length = 3
    cb.info = attributes(node)[:lang]
    n = CM.Node(cb)
    text = gettext(node)
    n.literal = endswith(text, '\n') ? text : text * '\n'
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:codeblock})
    cb = CM.CodeBlock()
    cb.is_fenced = true
    cb.fence_char = '`'
    cb.fence_length = 3
    cb.info = attributes(node)[:lang]
    n = CM.Node(cb)
    text = gettext(node)
    n.literal = endswith(text, '\n') ? text : text * '\n'
    append_ast_children!(n, node)

    return [block_attributes(node), n]
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

function to_commonmark_ast(node, ::Val{:blockquote})
    n = CM.Node(CM.BlockQuote())
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

function to_commonmark_ast(node, ::Val{:ol})
    n = CM.Node(CM.List())
    ld = CM.ListData()
    ld.padding = 2
    ld.bullet_char = '-'
    ld.type = :ordered
    n.t.list_data = ld
    node_ = cata(ch -> withtag(ch, :oli), node, SelectTag(:li))
    append_ast_children!(n, node_)
end


function to_commonmark_ast(node, ::Val{:li})
    n = CM.Node(CM.Item())
    ld = CM.ListData()
    ld.padding = 2
    ld.bullet_char = '-'
    n.t.list_data = ld
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:oli})
    n = CM.Node(CM.Item())
    ld = CM.ListData()
    ld.type = :ordered
    ld.padding = 2
    ld.bullet_char = '-'
    n.t.list_data = ld
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:table})
    alignment = if haskey(attributes(node), :align)
        attributes(node)[:align]
    else
        [:left]
    end
    n = CM.Node(CM.Table(alignment))
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:tableheader})
    n = CM.Node(CM.TableHeader())
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:tablebody})
    n = CM.Node(CM.TableBody())
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:tr})
    n = CM.Node(CM.TableRow())
    i = 0
    node = cata(node, SelectTag(:th) | SelectTag(:td)) do ch
        i += 1
        withattributes(ch, merge(attributes(ch), Dict(:column => i)))
    end
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Union{Val{:th}, Val{:td}})
    t = CM.TableCell(:left, true, get(attributes(node), :column, 1))
    n = CM.Node(t)
    append_ast_children!(n, node)
end

function to_commonmark_ast(node, ::Val{:coderesult})
    cb = CM.CodeBlock()
    cb.is_fenced = true
    cb.fence_char = '`'
    cb.fence_length = 3
    n = CM.Node(cb)
    n.literal = repr(only(children(only(children(node))))[]) * '\n'
    return [
        block_attributes(node),
        n,
    ]
end

function block_attributes(node::Node)
    attrs = Dict(string(k) => v for (k, v) in attributes(node))
    CM.Node(CM.Attributes(attrs, true))
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


@testset "MarkdownFormat rendering [format]" begin
    f = MarkdownFormat()
    roundtrip(s) = render(parse(s, f), f)
    @testset ":ol" begin
        s = """
         1. One
         2. Two
        """
        @test s == roundtrip(s)
    end
    @testset ":math" begin
        s = raw"""
        Inline math: $1 + 1$
        """
        @test s == roundtrip(s)
    end
    @testset ":mathblock" begin
        s = raw"""
        $$
        1 + 1
        $$
        """
        @test s == roundtrip(s)
    end
    @testset ":table" begin
        s = """
        | x | y |
        |:- |:- |
        | a | b |
        """
        @test s == roundtrip(s)
    end
end
