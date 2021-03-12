

function makedoctree(d::Dict)
    return XNode(:doctree, [XNode(:ul, [makedoctree(name, val) for (name, val) in d])])

end

function makedoctree(name::String, path)
    link = XNode(:a, Dict(:href => "/$path"), [XLeaf(name)])
    return XNode(:li, [link])
end


function makedoctree(name::String, d::Dict)
    return XNode(:li, [XLeaf(name), XNode(:ul, [makedoctree(n, val) for (n, val) in d])])
end


function loaddoctree(p::AbstractPath)
    xdoctree = Pollen.parse(p)
    xdoctree = cata(xdoctree, SelectTag(:a) & SelectHasAttr(:href)) do x
        href = attributes(x)[:href]
        if !startswith(href, '/')
            href = "/" * href
        end
        attributes(x)[:href] = href
        return x
    end
    return XNode(:doctree, [xdoctree])
end
