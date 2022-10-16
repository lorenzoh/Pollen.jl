"""
    ANSI(x)

Wraps a value with rich text display and adds an HTML display
that converts the ANSI escape sequences to valid HTML.
"""
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
    printer = ANSIColoredPrinters.HTMLPrinter(buf.io, root_class = "ansi")
    ANSIColoredPrinters.show_body(io, printer)
end

function Base.print(io::IO, ansi::ANSI)
    print(io, ansi.value)
end
