struct JSON <: Format end


formatextension(::JSON) = "json"



dict(x::Node) = Dict(
    :tag => tag(x),
    :attributes => attributes(x),
    :children => dict.(children(x))
)

# TODO: embed mime types
function dict(x::Leaf{<:AbstractString})
    return Dict(:mimes => Dict("text/plain" => x[]))

end

function dict(x::Leaf{Nothing})
    Dict(:mimes => Dict("text/plain" => ""))
end
function dict(x::Leaf)
    mimes = IJulia.display_dict(x[])
    d = Dict(:mimes => mimes)
end

function render!(io, x::XTree, format::JSON, val)
    JSON3.write(io, dict(x))
end


dict(x::Leaf{PreRendered}) = Dict(:mimes => x[].reprs)
