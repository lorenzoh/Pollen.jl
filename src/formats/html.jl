
Base.@kwdef struct HTMLFormat <: Format
    stripbody = true
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

function xtree(htmlnode::Gumbo.HTMLElement{S}) where S
    attrs = Dict{Symbol, Any}(Symbol(key) => val for (key, val) in htmlnode.attributes)
    return Node(S, XTree[xtree(c) for c in htmlnode.children], attrs)
end

function xtree(htmltext::Gumbo.HTMLText)
    return Leaf(htmltext.text)
end

# ## Rendering

render!(io, doc::Node, format::HTMLFormat) = render!(io, doc, format, Val(doc.tag))

function render!(io, x::Node, format::HTMLFormat, ::Val)
    print(io, "<", x.tag)
    if !isempty(x.attributes)
        print(io, " ")
        for (name, attr) in x.attributes
            print(io, string(name), "=", attr, ' ')
        end
    end
    print(io, ">")
    foreach(child -> render!(io, child, format), children(x))
    print(io, "</", x.tag, ">")
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


#=
function render!(io, x::Leaf{PreRendered}, ::HTMLFormat)
    reprs = x[].reprs
    for mime in HTMLFormat_MIMES
        if mime in keys(reprs)
            print(io, adapthtmlstr(mime, reprs[mime]))
            return
        end
    end
    error("Could not find mime for $(x[])!")
end
=#

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
    :wbr
]
