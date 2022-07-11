"""
    abstract type Format

A `Format` describes a content format that trees can be read from
and/or trees can be converted to.

## Extending

A `Format` `F` can implement the following methods:

- [`parse`](#)`(::IO, ::F`)::XTree` reads a tree
- [`render!`](#)`(::IO, ::XTree, ::F` writes a tree

"""
abstract type Format end


"""
    parse(io, format)
    parse(path, format)
    parse(str, format)

Parse source in `format` into a tree. Input can come from an `io::IO` or
a string `str`.
"""
parse(path::AbstractPath, format) = parse(open(path), format)
parse(s::String, format) = parse(IOBuffer(s), format)


"""
    parse(path)

Parse source in `AbstractPath` `path` into a tree. [`extensionformat`](#)
is used to find the correct [`Format`](#) to use.

"""
function parse(path::AbstractPath)
    format = extensionformat(Val(Symbol(extension(path))))
    return parse(path, format)
end

"""
    extensionformat(Val(Symbol(ext)))

Define a default `Format` for parsing files with extension `ext`.

For example `extensionformat(Val(:html)) == HTMLFormat()`, so `parse(p"index.html")`
dispatches to `parse(p"index.html", HTMLFormat())`
"""
function extensionformat(::Val{:ext}) end
extensionformat(file::String) = extensionformat(Val(Symbol(extension(Path(file)))))

function formatextension end

# output interface

function render!(path::AbstractPath, doc::XTree, format)
    open(path, "w") do f
        render!(f, doc, format)
    end
end


function render(doc, format)
    io = IOBuffer()
    render!(io, doc, format)
    return String(take!(io))
end


@testset "Format [interface]" begin
    struct TestFormat <: Format end
    Pollen.parse(io::IO, ::TestFormat) = Node(:doc, Leaf.(split(read(io, String))))
    Pollen.render!(io::IO, node::Node, ::TestFormat) = write(io, join(getindex.(children(node)), " "))

    format = TestFormat()
    @test render(parse("hello world", format), TestFormat()) == "hello world"
end
