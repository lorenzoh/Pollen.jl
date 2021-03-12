# AddIDs

const SEL_H1234 = SelectOr(SelectTag.((:h1, :h2, :h3, :h4)))
const SEL_H234 = SelectOr(SelectTag.((:h2, :h3, :h4)))

"""
    AddID(selector = sel"h2, h3, h4"; idfn)

`Replacer` that adds an `id` attribute to every x-expression
selected by `selector`. It assumes that its first child is a `String`.
The id is created by applying `idfn` to that string. `idfn` defaults
to `CommonMark.slugify`.
"""
AddID(sel=SEL_H234; idfn=CommonMark.slugify) =
    Replacer(x -> addid(x; idfn=idfn), sel)


function addid(x; idfn=CommonMark.slugify)
    #(!isempty(children(x)) && children(x)[1] isa String) || error(
    #    "To add an ID, first child must be a `String`. Got xexpr\n$doc")
    text = gettext(x)
    #text = children(x)[1]
    id = idfn(text)
    return withattributes(x, Dict(:id => id))
end


# HTMLify

function HTMLify(sel=SelectNode(), htmltag=:div)
    return Replacer(sel) do x
        htmlify(x, htmltag)
    end
end


"""
    htmlify(doc, htmltag = :div)

If `doc.tag` is not a valid HTML tag, changes it into a :div and adds the attribute
`:class => doc.tag`.
"""
function htmlify(doc, htmltag=:div)
    if tag(doc) in HTMLTAGS
        return doc
    else
        return XNode(
            htmltag,
            # TODO: add to classes if exist
            merge(attributes(doc), Dict(:class => string(tag(doc)))),
            children(doc),
        )
    end
end


# ChangeLinkExtensions

function ChangeLinkExtension(ext, sel::Selector = SelectTag(:a); linkattr = :href)
    return Replacer(x -> changelinkextension(x, ext; attr = linkattr), sel)
end


function changelinkextension(doc::XNode, ext; attr = :href)
    if haskey(attributes(doc), attr)
        href = doc.attributes[attr]
        return withattributes(
            doc,
            merge(doc.attributes, Dict(attr => changehrefextension(href, ext))),
        )
    else
        return doc
    end
end

# ChangeTag

function ChangeTag(t, sel)
    return Replacer(x -> withtag(x, t), sel)
end


# FormatCode

function FormatCode(codesel = SelectTag(:pre))
    return Replacer(x -> formatcodeblock(x), codesel)
end


function formatcodeblock(doc)
    if get(attributes(doc), :lang, "") == "julia"
        code = gettext(doc)
        try
            code = format_text(code)
        catch
            @info "Parsing error when formatting code snippet: \n\n$code"
        end
        return withchildren(doc, [XNode(:code, XLeaf(code))])
    else
        return doc
    end

end
