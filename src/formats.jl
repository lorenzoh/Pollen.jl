abstract type Format end


# input interface



"""
    parse(io, format)
    parse(path, format)
    parse(str, format)
"""
parse(path::AbstractPath, format) = parse(open(path), format)
parse(s::String, format) = parse(IOBuffer(s), format)


function parse(path::AbstractPath)
    format = extensionformat(Val(Symbol(extension(path))))
    return parse(path, format)
end

"""
    extensionformat(Val(Symbol(ext)))

Define a default `Format` for parsing files with extension `ext`.html

For example `extensionformat(Val(:html)) == HTML()`, so `parse(p"index.html")`
relays to `parse(p"index.html", HTML())`
"""
function extensionformat(::Val{:ext}) end

# output interface


"""
    render!(io, doc::XExpr, format, tag = Val(doc.tag))
"""
render!(io, doc::XExpr, format) = render!(io, doc, format, Val(doc.tag))

function render!(path::AbstractPath, doc::XExpr, format)
    open(path, "w") do f
        render!(f, doc, format)
    end
end


function render(doc, format)
    io = IOBuffer()
    render!(io, doc, format)
    return String(take!(io))
end
