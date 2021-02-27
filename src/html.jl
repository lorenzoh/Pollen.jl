
struct HTML <: Format end

# Parsing

function parse(io::IO, format::HTML)
    return parse(read(io, String), format)

end

function parse(s::String, ::HTML)
    return xexpr(Gumbo.parsehtml(s).root)
end

extensionformat(::Val{:html}) = HTML()

function xexpr(htmlnode::Gumbo.HTMLElement{S}) where S
    attrs = Dict{Symbol, Any}(Symbol(key) => val for (key, val) in htmlnode.attributes)
    return xexpr(S, attrs, htmlnode.children...)
end

function xexpr(htmltext::Gumbo.HTMLText)
    return htmltext.text
end

# Rendering

function render!(io, x::XExpr, format::HTML, ::Val)
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


function render!(io, s::String, ::HTML)
    print(io, s)
end


struct CSS <: Format end

function parse(io::IO, format::CSS)
    return xexpr(:style, read(io, String))
end


extensionformat(::Val{:css}) = CSS()


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
