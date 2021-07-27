struct JSON <: Format end


formatextension(::JSON) = "json"



dict(x::XNode) = Dict(
    :tag => tag(x),
    :attributes => attributes(x),
    :children => dict.(children(x))
)

# TODO: embed mime types
function dict(x::XLeaf{<:AbstractString})
    return Dict(:mimes => Dict("text/plain" => x[]))

end

function dict(x::XLeaf{Nothing})
    Dict(:mimes => Dict("text/plain" => ""))
end
function dict(x::XLeaf)
    mimes = IJulia.display_dict(x[])
    d = Dict(:mimes => mimes)
end

function render!(io, x::XTree, format::JSON, val)
    JSON3.write(io, dict(x))
end


dict(x::XLeaf{PreRendered}) = Dict(:mimes => x[].reprs)
