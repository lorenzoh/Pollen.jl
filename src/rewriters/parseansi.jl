
const DEFAULT_ANSISELECTOR = (SelectTag(:codeoutput) | SelectTag(:coderesult))

Base.@kwdef struct ParseANSI <: Rewriter
    sel::Selector = DEFAULT_ANSISELECTOR
end


function rewritedoc(rewriter::ParseANSI, _, doc)
    cata(doc, rewriter.sel) do node
        if length(children(node)) == 1 && tag(only(children(node))) === :codeblock
            str = only(children(node)).children[1]
            return withchildren(node, [
                parseansi(str)
            ])
        else
            return node
        end
    end
end


function parseansi(str::String)
    return withtag(Pollen.parse(ansistringtohtml(str), HTMLFormat()), :ansi)
end

function ansistringtohtml(str::String)
    buf = IOBuffer()
    printer = ANSIColoredPrinters.HTMLPrinter(IOBuffer(str), root_tag="ansi")
    ANSIColoredPrinters.show_body(buf, printer)
    return String(take!(buf))
end


@testset "ParseANSI" begin
    s = "\e[31m\e[1mhi\e[22m\e[39m"
    @test parseansi(s) == Node(:ansi,
        Node(:span,
            Node(:span, "hi", class = "sgr1"),
            class = "sgr31"))

end

#

struct ANSI{T}
    value::T
end


function Base.show(io::IO, mime::MIME"text/plain", ansi::ANSI)
    print(io, "ANSI(")
    show(io, mime, ansi.value)
    print(io, ")")
end

function Base.show(io::IO, mime::MIME"text/html", ansi::ANSI)
    if showable(mime, ansi.value)
        return show(io, mime, ansi.value)
    end
    buf = IOContext(IOBuffer(), :color => true, :compact => false, :short => false)
    print(buf, ansi.value)
    printer = ANSIColoredPrinters.HTMLPrinter(buf.io, root_class="ansi")
    ANSIColoredPrinters.show_body(io, printer)
end


function Base.print(io::IO, ansi::ANSI)
    print(io, ansi.value)
end
