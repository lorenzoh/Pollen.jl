struct PrepareQuarto <: Rewriter
end


function Pollen.rewritedoc(rewriter::PrepareQuarto, docid, doc::Node)
    doc = remove_title(doc)
    return doc
end

@option struct ConfigPrepareQuarto <: Pollen.AbstractConfig end
Pollen.configtype(::Type{PrepareQuarto}) = ConfigPrepareQuarto
Pollen.from_config(::ConfigPrepareQuarto) = PrepareQuarto()


#=
function Pollen.postbuild(rewriter::ConfigureQuarto, _, builder::Pollen.FileBuilder)
    YAML.write_file(joinpath(string(builder.dir), "_quarto.yml"), rewriter.quartoconfig)
end
=#


# TODO: render ref documents usefully

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
