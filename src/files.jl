function parsefiletree(p::AbstractPath; exts = ("md",))
    tree = FileTree(p)
    tree = filter(f -> extension(path(f)) in exts, tree, dirs=false)
    tree = filter(f -> !startswith(name(f), '.'), tree)
    tree = FileTrees.load(f -> Pollen.parse(path(f)), tree, dirs = false)
    return tree
end

parsefiletree(dir::String) = parsefiletree(Path(dir))

function savefiletree(tree, dst::AbstractPath, format::Pollen.Format)
    tree = rename(tree, dst)
    FileTrees.save(tree) do f
        p = withext(joinpath(dst, path(f)), formatextension(format))
        render!(p, f[], format)
    end
end

function withext(path::AbstractPath, ext)
    return joinpath(parent(path), "$(filename(path)).$ext")
end


function hasfile(tree::FileTree, p)
    try
        tree[p]
        return true
    catch
        return false
    end
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
