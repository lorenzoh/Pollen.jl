
struct Jupyter <: Format end

extensionformat(::Val{:ipynb}) = Jupyter()


function parse(io::IO, format::Jupyter)
    return parse(JSON3.read(io), format)
end


function parse(obj::JSON3.Object, format::Jupyter)
    cs = XTree[]
    lang = get(get(get(obj, :metadata, Dict()), :language_info, Dict()), :name, "")
    for cell in obj[:cells]
        cs = vcat(cs, children(parsejupytercell(cell, lang)))
    end
    return XNode(
        :body,
        cs
    )
end


function parsejupytercell(cell, lang = "")
    type = cell[:cell_type]
    if  type == "markdown"
        return parsejupytercellmd(cell)
    elseif type == "code"
        return parsejupytercellcode(cell, lang)
    else
        error("Unsupported cell type $type.")
    end
end


function parsejupytercellmd(cell)
    return parse(join(cell[:source], "\n"), Markdown())
end

function parsejupytercellcode(cell, lang)
    code = join(cell[:source])
    xcode = XNode(:pre, Dict(:lang => lang), [XNode(:code, [XLeaf(code)])])
    cs = XTree[xcode]

    outputs = cell[:outputs]
    stream = ""
    for output in outputs
        if output[:output_type] == "stream"
            stream *= join(output[:text])
        elseif output[:output_type] == "execute_result"
            # Add concatenated outputs first
            push!(cs, viewcodeoutput(stream))
            stream = ""

            # The handle result
            reprs = Dict(MIME(k) => join(v) for (k, v) in output[:data])
            push!(cs, viewcoderesult(PreRendered(reprs)))
        end
    end

    return XNode(
        :div,
        Dict(:class => "cellcontainer"),
        cs,
    )
end


struct PreRendered
    reprs::Dict
end

Base.show(io::IO, prerendered::PreRendered) = print(io,
    "Prerendered() with $(length(prerendered.reprs)) reprs")

function render!(io, x::XLeaf{PreRendered}, ::HTML)
    reprs = x[].reprs
    for mime in HTML_MIMES
        if mime in keys(reprs)
            print(io, adapthtmlstr(mime, reprs[mime]))
            return
        end
    end
    error("Could not find mime for $(x[])!")
end


Base.showable(mime::MIME, x::PreRendered) = mime in keys(x.reprs)
