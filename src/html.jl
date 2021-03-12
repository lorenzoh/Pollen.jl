
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
    return XNode(S, attrs, XTree[convert(XTree, c) for c in htmlnode.children])
end

function Base.convert(::Type{XTree}, htmltext::Gumbo.HTMLText)
    return XLeaf(htmltext.text)
end

# Rendering

function render!(io, x::XNode, format::HTML, ::Val)
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


function render!(io, x::XLeaf{<:AbstractString}, ::HTML)
    print(io, CommonMark.escape_xml(x[]))
end

const HTML_MIME_TYPES = [
    IJulia.ijulia_mime_types[3],
    IJulia.ijulia_mime_types[4],
    IJulia.ijulia_mime_types[1],
    IJulia.ijulia_mime_types[2],
    IJulia.ijulia_mime_types[5],
]

function render!(io, x::XLeaf, ::HTML)
    val = x[]

    for m in HTML_MIME_TYPES
        try
            if IJulia._showable(m, val)
                mime, mime_repr = IJulia.display_mimestring(m, val)
                print(io, mime_repr)
                return
            end
        catch
            if m == MIME("text/plain")
                rethrow() # text/plain is required
            end
        end
    end
    #=
    # Try to render as image
    mimedict = IJulia.display_dict(a)
    for mime in IMAGEMIMES
        if mime in keys(mimedict)
            src = "data;$mime;base64,$(mimedict[mime])"
            return render!(io, xexpr(:img, Dict(:src => src)), HTML(), Val(:img))
        end
    end
    @show showable(MIME("text/html"), a)
    error("Could not render $a as HTML.")
    =#
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
