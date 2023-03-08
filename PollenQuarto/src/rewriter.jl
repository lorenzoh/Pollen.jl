struct ConfigureQuarto <: Rewriter
    quartoconfig::Dict
end

Base.show(io::IO, ::ConfigureQuarto) = print(io, "ConfigureQuarto()")

function Pollen.rewritedoc(rewriter::ConfigureQuarto, docid, doc::Node)
    doc = remove_title(doc)

    return doc
end

function Pollen.postbuild(rewriter::ConfigureQuarto, _, builder::Pollen.FileBuilder)
    YAML.write_file(joinpath(string(builder.dir), "_quarto.yml"), rewriter.quartoconfig)
end


## Helpers

function remove_title(doc::Pollen.Node)
    if !isempty(children(doc))
        ch = children(doc)[1]
        if ch isa Node && tag(ch) === :h1
            return Pollen.withchildren(doc, children(doc)[2:end])
        end
    end
    return doc
end
