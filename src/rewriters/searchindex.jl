struct SearchIndex <: Rewriter
    path::String
end
SearchIndex() = SearchIndex("documents.json")


function postbuild(searchindex::SearchIndex, project, builder::FileBuilder)
    docs = filter(((p, doc),) -> !startswith(string(p), "source"), project.outputs)
    index = map(lunr_document, keys(docs), values(docs))

    dst = joinpath(builder.dir, searchindex.path)
    mkpath(parent(dst))

    open(dst, "w") do f
        JSON3.write(f, index)
    end
end

function lunr_document(path, doc)
    id = string(path)
    if startswith(id, "references")
        return Dict(
            "id" => id,
            "text" => join(getsearchindexterms(doc), " "),
            "title" => get(attributes(doc), :title, string(path)),
            "doctype" => "documentation",
        )
    elseif startswith(id, "sourcefiles")
        return Dict(
            "id" => id,
            "text" => join(getsearchindexterms(doc), " "),
            "title" => get(attributes(doc), :title, string(path)),
            "doctype" => "sourcefile",
        )
    else
        return Dict(
            "id" => id,
            "text" => join(getsearchindexterms(doc), " "),
            "title" => get(attributes(doc), :title, string(path)),
            "doctype" => "document",
        )
    end

end


function getsearchindexterms(doc::Node)
    terms = String[]
    for node in select(doc, SelectTag(:julia))
        foreach(_getjuliacodeterms(node)) do term
            push!(terms, term)
        end
    end
    for leaf in select(filter(doc, !SelectTag(:codeblock)), Pollen.SelectLeaf())
        leaf isa Leaf{String} || continue
        foreach(_getterms(leaf[])) do term
            push!(terms, term)
        end
    end
    return terms
end

function _getjuliacodeterms(node::Node)
    (only(children(id))[] for id in select(node, SelectTag(:IDENTIFIER)))
end

function _getterms(str::String)
    return (strip(s, PUNCTUATION) for s in split(str, " "))
end


const PUNCTUATION = Char.(codeunits( "!\"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~"))
