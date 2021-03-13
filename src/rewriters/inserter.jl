
struct Inserter <: Rewriter
    fs
    positions
end

function Inserter(pairs::AbstractVector)
    Inserter(getindex.(pairs, 1), getindex.(pairs, 2))
end

Base.show(io::IO, inserter::Inserter) = print(io, "Inserter($(inserter.positions))")

function updatefile(inserter::Inserter, p::AbstractPath, doc::XNode)
    for (f, pos) in zip(inserter.fs, inserter.positions)
        if isnothing(selectfirst(doc, pos.selector))
            error("Could not find position $pos to insert into.")
        end
        doc = insertfirst(doc, f(p, doc), pos)
    end
    return doc
end



function toccreator(;
    docsel = SelectTag(:article),
    hierarchysels = SelectTag.((:h2, :h3, :h4)))
    return function createtoc(p, doc)
        content = selectfirst(doc, docsel)
        if isnothing(content)
            error("Could not find contents at $docsel to create a table of contents from.")
        end
        return maketoc(content, hierarchysels)
    end
end
