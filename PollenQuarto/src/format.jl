Base.@kwdef struct QuartoMarkdownFormat <: Pollen.Format
    md::MarkdownFormat = MarkdownFormat()
end


Pollen.parse(io::IO, format::QuartoMarkdownFormat) =
    Pollen.parse(io, format.md)
Pollen.render!(io::IO, tree, format::QuartoMarkdownFormat) =
    Pollen.render!(io, tree, format.md)

Pollen.extensionformat(::Val{:qmd}) = QuartoMarkdownFormat()
Pollen.formatextension(::QuartoMarkdownFormat) = "qmd"


# TODO: change how admonitions are rendered