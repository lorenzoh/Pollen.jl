

function makedoctree(d::Dict)
    return Node(:doctree, [Node(:ul, [makedoctree(name, val) for (name, val) in d])])

end

function makedoctree(name::String, path)
    link = Node(:a, Dict(:href => "/$path"), [Leaf(name)])
    return Node(:li, [link])
end


function makedoctree(name::String, d::Dict)
    return Node(:li, [Leaf(name), Node(:ul, [makedoctree(n, val) for (n, val) in d])])
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
    return Node(:doctree, [xdoctree])
end
