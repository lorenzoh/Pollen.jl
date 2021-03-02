
function rewrite(doc::XExpr, transforms)
    for (f, sel) in transforms
        doc = map(f, doc, sel)
    end
    return doc
end

# Change tag

struct ChangeTag
    to::Symbol
end

(changetag::ChangeTag)(doc) = xexpr(changetag.to, doc.attributes, doc.children...)

# Slug IDs

struct AddSlugID end


function (slugid::AddSlugID)(doc)
    doc.children[1] isa String || error("To add an ID, first child must be a `String`. Got xexpr\n$doc")
    return xexpr(
        doc.tag,
        merge(doc.attributes, Dict(:id => CommonMark.slugify(doc.children[1]))),
        doc.children
    )
end

# Table of contents

struct AddTableOfContents{N}
    tags::NTuple{N, Symbol}
    after::Selector
end

AddTableOfContents() = AddTableOfContents((:h2, :h3, :h4), SelectTag(:h1))

function (toc::AddTableOfContents)(doc)
    return insertafter(toc.after, doc, xexpr(:toc, maketoc(doc, toc.tags)))
end



"""
    maketoc(doc, tags)

Create a table of contents with a hierarchy given by `tags`.
"""
function maketoc(doc::XExpr, tags::NTuple{N, Symbol}) where N

    # select heading tags and content groups between them
    sel = SelectTag(tags[1])
    headings = select(doc, sel)
    groups = @view collect(groupchildren(doc, sel))[2:end]

    # construct ToC recursively
    return xexpr(:ul, [maketoclistitem(h, g, tags) for (h, g) in zip(headings, groups)]...)
end


"""
    maketoclistitem(heading, group, tags)

Make a list item in a table of contents. If `tags` is not empty, recursively
create a hierarchical table of contents.
"""
function maketoclistitem(heading, group, tags)
    heading.children[1] isa String || error("Headings selected in ToC must have a `String` as the first child")
    haskey(heading.attributes, :id) || error("Headings selected in ToC need to have an `:id` field. See `AddSlugID`.")
    link = xexpr(:a, Dict(:href => "#$(heading.attributes[:id])"), heading.children[1])
    if length(tags) > 1
        return xexpr(:li, link, maketoc(group, tags[2:end]))
    else
        return xexpr(:li, link)
    end
end


"""
    groupchildren(doc, sel)

Group children of `doc` by `sel`. Each group consists of a selector match
followed by other children until (excluding) the next match. Groups are
returned as x-expressions with the root tag `:group`.

```julia
doc = xexpr(:doc,
    (:h1, "Title 1"),
    "Text 1",
    (:h1, "Title 2"),
    "Text 2")

collect(groupchildren(doc, SelectTag(:h1))) == [
    xexpr(:group),
    xexpr(:group, (:h1, "Title 1"), "Text 1"),
    xexpr(:group, (:h1, "Title 2"), "Text 2"),
]
```
"""
function groupchildren(doc::XExpr, sel::Selector)
    groups = [[]]
    groupidx = 1
    for child in doc.children
        if matches(sel, child)
            groupidx += 1
            push!(groups, [child])
        else
            push!(groups[groupidx], child)
        end
    end
    return (xexpr(doc.tag, doc.attributes, group...) for group in groups)
end


# MakeHTMLTags

"""
    htmlify(doc, htmltag = :div)

If `doc.tag` is not a valid HTML tag, changes it into a :div and adds the attribute
`:class => doc.tag`.
"""
function htmlify(doc, htmltag = :div)
    if doc.tag in HTMLTAGS
        return doc
    else
        return xexpr(
            htmltag,
            merge(doc.attributes, Dict(:class => string(doc.tag))),
            doc.children...,
        )
    end
end


struct ChangeLinkExtensions
    ext
    linkattr
end

ChangeLinkExtensions(ext = "html") = ChangeLinkExtensions(ext, :href)


function (chle::ChangeLinkExtensions)(doc::XExpr)
    @show doc
    if haskey(doc.attributes, chle.linkattr)
        href = doc.attributes[chle.linkattr]
        @show href
        return xexpr(
            doc.tag,
            merge(doc.attributes, Dict(chle.linkattr => changehrefextension(href, chle.ext))),
            doc.children,
        )
    else
        return doc
    end
end
