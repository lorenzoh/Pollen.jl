"""
    JSONFormat() <: Format

Format for reading and writing trees from and to JSON.

Trees nodes are encoded as JSON objects:

```julia-repl
julia> render(Node(:p, "Hello", nothing), JSONFormat()) |> println

{"attributes":{},"tag":"p","children":["Hello", null]}
```

Encoding to JSON is lossless only when leaf and attribute values
are valid JSON types. Richer leaf values will be converted to
a dictionary of MIME type representations to allow serialization
and rich display upon deserialization.
"""
Base.@kwdef struct JSONFormat <: Format
    mimes = MIMES
    firstmimeonly = true
end

formatextension(::JSONFormat) = "json"

# Outputting JSON

"""
    tojson(::JSONFormat, tree)

Convert a `tree` into a JSON-compatible representation, i.e.
one that only uses JSON datatypes (`Dict`, `String`, `Number`, `Nothing`).
"""
function tojson end

tojson(tree::XTree) = tojson(JSONFormat(), tree)
function tojson(format::JSONFormat, node::Node)
    Dict(:type => "node",
         :tag => tag(node),
         :children => [tojson(format, ch) for ch in children(node)],
         :attributes => attributes(node))
end

tojson(::JSONFormat, ::Leaf{Nothing}) = nothing
tojson(::JSONFormat, leaf::Leaf{String}) = leaf[]

# non-primitive leaf values are stored as mimetype dicts
function tojson(format::JSONFormat, leaf::Leaf)
    mimestrings = asmimestrings(leaf[], format.mimes; firstonly = format.firstmimeonly)
    return Dict(:type => "leaf", :mimes => mimestrings)
end

function render!(io::IO, tree::XTree, ::JSONFormat)
    JSON3.write(io, tojson(tree))
end

# Inputting JSON

function parse(io::IO, format::JSONFormat)
    data = JSON3.read(io)
    return fromjson(format, data)
end

function fromjson end
fromjson(data) = fromjson(JSONFormat(), data)

function fromjson(format::JSONFormat, data::Union{<:Dict, <:JSON3.Object})
    type = data[:type]
    if type == "leaf"
        return Leaf(PreRendered(Dict(MIME(m) => val for (m, val) in data[:mimes])))
    elseif type == "node"
        return Node(Symbol(data[:tag]),
                    XTree[fromjson(format, ch) for ch in data[:children]],
                    Dict(data[:attributes]))
    else
        throw(ArgumentError("Could not parse a tree from JSON data $(data)"))
    end
end

fromjson(::JSONFormat, ::Nothing) = Leaf(nothing)
fromjson(::JSONFormat, str::String) = Leaf(str)

# `PreRendered` allows reading back in leaf values with rich types
# that were converted to mime representations.
struct PreRendered
    mimestrings::Dict{MIME, String}
end

prerender(x) = PreRendered(asmimestrings(x, MIMES; firstonly = false))

function asmimestrings(x::PreRendered, mimes = MIMES; firstonly = false)
    mimestrings = Dict{MIME, String}()
    for mime in mimes
        if mime in keys(x.mimestrings)
            mimestrings[mime] = x.mimestrings[mime]
            firstonly && break
        end
    end
    return mimestrings
end

function Base.show(io::IO, pre::PreRendered)
    print(io,
          "Prerendered($(collect(keys(pre.mimestrings))))")
end

@testset "JSONFormat" begin
    format = JSONFormat(firstmimeonly = false)

    @testset "Leaves" begin
        @test render(Leaf("Hello"), format) == "\"Hello\""
        @test render(Leaf(nothing), format) == "null"
    end

    @testset "PreRendered" begin
        leaf = Leaf(Base.HTML("<p>Hello</p>"))
        leaf_ = parse(render(leaf, format), format)
        @test leaf_ isa Leaf{PreRendered}
        @test leaf_[].mimestrings[MIME("text/html")] == "<p>Hello</p>"
    end

    @testset "Round-trip" begin
        tree = Node(:doc, Node(:p, "hi", nothing; attr = "val"))
        @test Pollen.parse(Pollen.render(tree, format), format) == tree
    end
end
