

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
