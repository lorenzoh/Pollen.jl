
function withext(path::AbstractPath, ext)
    newname = filename(path)
    for e in extensions(path)
        newname *= "."
        newname *= e
    end
    newname *= "."
    newname *= ext
    return joinpath(parent(path), newname)
end


const RE_HREF = r"(.*)#(.*)"

# TODO: refactor
function changehrefextension(href, ext)
    m = match(RE_HREF, href)
    # Does not have an ID
    if isnothing(m)
        if href == ""
            return ""
        else
            return string(withext(Path(href), ext))
        end
    # Has an ID
    else
        ref, id = m[1], m[2]
        if ref == ""
            return "#$id"
        else
            ref_ = string(withext(Path(ref), ext))
            return "$ref_#$id"
        end
    end
end


function nodehref(node)
    return "/" * string(relative(path(node), path(root(node))))
end

root(node) = isnothing(parent(node)) ? node : root(parent(node))
