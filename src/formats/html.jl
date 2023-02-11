
"""
    HTMLFormat() <: Format

Format for HTML data. Supports both reading and writing.


## Examples

Reading HTML:

{cell}
```julia
using Pollen
format = HTMLFormat()
node = Pollen.parse("<div class=\"group\"><span>Hi there!</span></div>", format)
```

{cell}
```julia
Pollen.render(node, format)
```
"""
Base.@kwdef struct HTMLFormat <: Format
    stripbody = true
    defaulttag::Union{Symbol, Nothing} = :div
end

# ## Parsing

function parse(io::IO, format::HTMLFormat)
    return parse(read(io, String), format)
end

function parse(s::String, format::HTMLFormat)
    doc = withtag(xtree(Gumbo.parsehtml(s).root), :html)
    if format.stripbody
        doc = withtag(doc.children[2], :html)
    end
    return doc
end

extensionformat(::Val{:html}) = HTMLFormat()

function xtree(htmlnode::Gumbo.HTMLElement{S}) where {S}
    attrs = Dict{Symbol, Any}(Symbol(key) => val for (key, val) in htmlnode.attributes)
    return Node(S, XTree[xtree(c) for c in htmlnode.children], attrs)
end

function xtree(htmltext::Gumbo.HTMLText)
    return Leaf(htmltext.text)
end

# ## Rendering

render!(io, doc::Node, format::HTMLFormat) = render!(io, doc, format, Val(doc.tag))

function render!(io, x::Node, format::HTMLFormat, ::Val)
    if tag(x) in HTMLFormatTAGS || isnothing(format.defaulttag)
        print(io, "<", x.tag)
        if !isempty(x.attributes)
            print(io, " ")
            for (i, (name, attr)) in enumerate(x.attributes)
                print(io, string(name), "=\"", attr, "\"")
                i != length(x.attributes) && print(io, " ")
            end
        end
        print(io, ">")
        foreach(child -> render!(io, child, format), children(x))
        print(io, "</", x.tag, ">")
    else
        node = Node(
            tag=format.defaulttag,
            children=children(x),
            attributes=merge(attributes(x), Dict(:class => tag(x)))
        )
        render!(io, node, format)
    end
end

const HTML_MIMES = [
    MIME"image/png"(),
    MIME"image/jpeg"(),
    MIME"image/svg+xml"(),
    #MIME"text/markdown"(),
    MIME"text/html"(),
    #MIME"text/latex"(),
    MIME"text/plain"(),
]

function render!(io, x::Leaf, ::HTMLFormat)
    if showable(MIME"text/html"(), x)
        show(io, MIME"text/html"(), x[])
    else
        show(io, MIME"text/plain"(), x[])
    end
end

function render!(io, node::Node, format::HTMLFormat, ::Val{:codecell})
    codeattrs, outputattrs, resultattrs = __parsecodeattributes(attributes(node))

    # Render code
    render!(io, Node(:codeblock, children(node), codeattrs), format)

    # Render output printed while executing code
    if !isnothing(outputattrs[:value]) && get(outputattrs, :show, "true") == "true"
        value = outputattrs[:value]
        if value != ""
            attrs = delete!(merge(outputattrs, Dict(:class => "codeoutput")), :value)
            outputnode = Node(:codeblock, [Leaf(ANSI(value))], attrs)
            render!(io, outputnode, format)
        end
    end
    # Render result of executed code
    if !isnothing(resultattrs[:value]) && get(resultattrs, :show, "true") == "true"
        value = resultattrs[:value]
        attrs = delete!(merge(resultattrs, Dict(:class => "coderesult")), :value)
        resultnode = if hasrichdisplay(value)
            Node(:div, [Leaf(value)], attrs)
        else
            Node(:codeblock, [Leaf(ANSI(value))], attrs)
        end
        render!(io, resultnode, format)
    end
end

function render!(io, node::Node, format::HTMLFormat, ::Val{:codeblock})
    render!(io, Node(:pre, Node(:code, children(node), attributes(node))), format)
end

function render!(io, node::Node, format::HTMLFormat, ::Val{:julia})
    node = Node(:span, children(node), merge(attributes(node), Dict(:class => "julia")))
    render!(io, node, HTMLFormat(defaulttag=:span))
end

function htmlstr(mime::MIME, x)
    s = IJulia.limitstringmime(mime, x)
    return adapthtmlstr(mime, s)
end

adapthtmlstr(::MIME, s) = s

function adapthtmlstr(::MIME{Symbol("image/png")}, s)
    return """<img src="data:image/png;base64,$s"/>"""
end

function adapthtmlstr(::MIME{Symbol("image/jpeg")}, s)
    return """<img src="data:image/jpeg;base64,$s"/>"""
end

function render!(io, x::Leaf{<:AbstractString}, ::HTMLFormat)
    print(io, x[])
end

const IMAGEMIMES = [
    "image/jpeg",
    "image/svg+xml",
    "image/png",
    "image/gif",
]

formatextension(::HTMLFormat) = "html"

# ## Tests

@testset "HTMLFormat [format]" begin
    format = HTMLFormat()
    @test parse("<b>hi</b>", format) == Node(:html, Node(:b, "hi"))
    @test parse("<b x=\"yo\">hi</b>", format) == Node(:html, Node(:b, "hi"; x = "yo"))
    @testset "Round-trip" begin
        s = "<html><b x=yo >hi</b></html>"
        @test render(parse(s, format), format) == s
    end
end

# Constants

const HTMLFormatTAGS = [
    :DOCTYPE,
    :a,
    :abbr,
    :acronym,
    :address,
    :applet,
    :area,
    :article,
    :aside,
    :audio,
    :b,
    :base,
    :basefont,
    :bdi,
    :bdo,
    :big,
    :blockquote,
    :body,
    :br,
    :button,
    :canvas,
    :caption,
    :center,
    :cite,
    :code,
    :col,
    :colgroup,
    :data,
    :datalist,
    :dd,
    :del,
    :details,
    :dfn,
    :dialog,
    :dir,
    :div,
    :dl,
    :dt,
    :em,
    :embed,
    :fieldset,
    :figcaption,
    :figure,
    :font,
    :footer,
    :form,
    :frame,
    :frameset,
    :h1,
    :h2,
    :h3,
    :h4,
    :h5,
    :h6,
    :head,
    :header,
    :hr,
    :html,
    :HTMLFormat,
    :i,
    :iframe,
    :img,
    :input,
    :ins,
    :kbd,
    :label,
    :legend,
    :li,
    :link,
    :main,
    :map,
    :mark,
    :meta,
    :meter,
    :nav,
    :noframes,
    :noscript,
    :object,
    :ol,
    :optgroup,
    :option,
    :output,
    :p,
    :param,
    :picture,
    :pre,
    :progress,
    :q,
    :rp,
    :rt,
    :ruby,
    :s,
    :samp,
    :script,
    :section,
    :select,
    :small,
    :source,
    :span,
    :strike,
    :strong,
    :style,
    :sub,
    :summary,
    :sup,
    :svg,
    :table,
    :tbody,
    :td,
    :template,
    :textarea,
    :tfoot,
    :th,
    :thead,
    :time,
    :title,
    :tr,
    :track,
    :tt,
    :u,
    :ul,
    :var,
    :video,
    :wbr,
]
