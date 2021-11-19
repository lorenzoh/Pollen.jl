
struct JuliaFile <: Format end

extensionformat(::Val{:jl}) = JuliaFile()
formatextension(::JuliaFile) = "jl"

function parse(io::IO, ::JuliaFile)
    s = String(read(io))
    return XNode(:sourcefile, [XLeaf(s)])
end
