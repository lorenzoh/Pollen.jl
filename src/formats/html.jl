
struct HTML <: Format end

# Parsing

function parse(io::IO, format::HTML)
    return parse(read(io, String), format)

end

function parse(s::String, ::HTML)
    return convert(XTree, Gumbo.parsehtml(s).root)
end

extensionformat(::Val{:html}) = HTML()

function Base.convert(::Type{XTree}, htmlnode::Gumbo.HTMLElement{S}) where S
    attrs = Dict{Symbol, Any}(Symbol(key) => val for (key, val) in htmlnode.attributes)
    return Node(S, attrs, XTree[convert(XTree, c) for c in htmlnode.children])
end

function Base.convert(::Type{XTree}, htmltext::Gumbo.HTMLText)
    return Leaf(htmltext.text)
end

# Rendering

function render!(io, x::Node, format::HTML, ::Val)
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

function render!(io, x::Leaf, ::HTML)
    val = x[]

    for m in HTML_MIMES
        try
            if IJulia._showable(m, val)
                s = htmlstr(m, val)
                print(io, s)
                return
            end
        catch
            if m == MIME("text/plain")
                rethrow() # text/plain is required
            end
        end
    end
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


function render!(io, x::Leaf{<:AbstractString}, ::HTML)
    print(io, ansistringtohtml(x[]))
end


function ansistringtohtml(s)
    buf = IOBuffer()
    printer = HTMLPrinter(IOBuffer(s), root_tag="span")
    ANSIColoredPrinters.show_body(buf, printer)
    #show(buf, MIME"text/html"(), )
    return String(take!(buf))
end


IMAGEMIMES = [
    "image/jpeg",
    "image/svg+xml",
    "image/png",
    "image/gif",
]


formatextension(::HTML) = "html"


# Constants

const HTMLTAGS = [
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
    :HTML,
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
