# Large parts of this file are adapted from IJulia.jl's source code to avoid its dependencies
# https://github.com/JuliaLang/IJulia.jl is published under the following license:
#
#     Copyright &copy; 2013 by Steven G. Johnson, Fernando Perez, Jeff Bezanson, Stefan Karpinski, Keno Fischer, and other contributors.
#
#     Permission is hereby granted, free of charge, to any person obtaining
#     a copy of this software and associated documentation files (the
#     "Software"), to deal in the Software without restriction, including
#     without limitation the rights to use, copy, modify, merge, publish,
#     distribute, sublicense, and/or sell copies of the Software, and to
#     permit persons to whom the Software is furnished to do so, subject to
#     the following conditions:
#
#     The above copyright notice and this permission notice shall be
#     included in all copies or substantial portions of the Software.
#
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#     EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#     NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#     LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#     OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#     WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#


# Default mimetypes in decreasing richness
const MIMES = [
    MIME"text/html"(),
    MIME"text/latex"(),
    MIME"image/svg+xml"(),
    MIME"image/png"(),
    MIME"image/jpeg"(),
    MIME"text/plain"(),
    MIME"text/markdown"(),
]


function asmimestrings(x, mimes = MIMES; firstonly = false)
    mimestrings = Dict{MIME, String}()
    for mime in mimes
        if showable(mime, x)
            mimestrings[mime] = asmimestring(x, mime)
            firstonly && break
        end
    end
    return mimestrings
end

function asmimestring(x, mimes::Vector{<:MIME} = MIMES)
    i = findfirst(m -> showable(m, x), mimes)
    isnothing(i) && throw(ArgumentError("Could not find a valid mimetype to display $x in mimes $mimes!"))
    mime = mimes[i]
    return mime, asmimestring(x, mime)
end


# IJulia inline.jl
israwtext(::MIME, x::AbstractString) = true
israwtext(::MIME"text/plain", x::AbstractString) = false
israwtext(::MIME, x) = false

InlineIOContext(io, KVs::Pair...) = IOContext(
    io,
    :limit=>true, :color=>true, :jupyter=>true,
    KVs...
)
function asmimestring(x, mime::MIME)
    buf = IOBuffer()
    if istextmime(mime)
        if israwtext(mime, x)
            return String(x)
        else
            show(InlineIOContext(buf), mime, x)
        end
    else
        b64 = Base64EncodePipe(buf)
        if isa(x, Vector{UInt8})
            write(b64, x) # x assumed to be raw binary data
        else
            show(InlineIOContext(b64), mime, x)
        end
        close(b64)
    end
    return String(take!(buf))
end
