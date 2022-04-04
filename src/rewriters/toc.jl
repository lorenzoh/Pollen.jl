

function AddTableOfContents(;
        bodysel = SelectTag(:body),
        contentsel = SelectTag(:article),
        hierarchysels = SelectTag.((:h2, :h3, :h4)),
        insertpos = After(SelectTag(:h1)),)
    return Replacer(bodysel) do body
        content = selectfirst(body, contentsel)
        if isnothing(content)
            error("Could not find contents to generate ToC from with selector $contentsel.")
        end
        tocnode = Node(:toc, [maketoc(content, hierarchysels)])
        return insertfirst(
            body,
            tocnode,
            insertpos)
    end
end


"""
    maketoc(doc, tags)

Create a table of contents with a hierarchy given by `tags`.
"""
function maketoc(doc::Node, sels::NTuple{N, Selector}) where N
    # select heading tags and content groups between them
    sel = sels[1]
    headings = collect(select(doc, sel))
    groups = collect(groupchildren(doc, sel))[2:end]

    # construct ToC recursively
    return Node(:ul, [maketoclistitem(h, g, sels) for (h, g) in zip(headings, groups)])
end


"""
    maketoclistitem(heading, group, tags)

Make a list item in a table of contents. If `tags` is not empty, recursively
create a hierarchical table of contents.
"""
function maketoclistitem(heading::Node, group, sels)
    haskey(heading.attributes, :id) || error("Headings selected in ToC need to have an `:id` field. See `AddSlugID`.")
    link = Node(:a, Dict(:href => "#$(heading.attributes[:id])"), [Leaf(gettext(heading))])
    if length(sels) > 1
        return Node(:li, [link, maketoc(group, sels[2:end])])
    else
        return Node(:li, [link])
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
function groupchildren(xtree::Node, sel::Selector)
    groups = [XTree[]]
    groupidx = 1
    for child in children(xtree)
        if matches(sel, child)
            groupidx += 1
            push!(groups, XTree[child])
        else
            push!(groups[groupidx], child)
        end
    end
    return (withchildren(xtree, group) for group in groups)
end
