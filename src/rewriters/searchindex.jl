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
    if startswith(id, "documents")
        return Dict(
            "id" => id,
            "text" => Pollen.gettext(doc, " "),
            "title" => get(Pollen.attributes(doc), :title, string(path)),
            "doctype" => "document",
        )
    elseif startswith(id, "references")
        return Dict(
            "id" => id,
            "text" => Pollen.gettext(doc, " "),
            "title" => get(Pollen.attributes(doc), :title, string(path)),
            "doctype" => "documentation",
        )
    elseif startswith(id, "sourcefiles")
        # Only index identifiers
        symbols = []
        for x in select(doc, SelectTag(:CST_IDENTIFIER))
            push!(symbols, gettext(x))
        end
        text = join(symbols, " ")
        return Dict(
            "id" => id,
            "text" => text,
            "title" => get(Pollen.attributes(doc), :title, string(path)),
            "doctype" => "sourcefile",
        )
    else
    end

end
