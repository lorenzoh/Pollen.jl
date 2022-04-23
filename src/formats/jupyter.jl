
"""
    JupyterFormat() <: Format

Format for reading in Jupyter notebook (.ipynb) files.


## Extended help

Markdown cells are parsed as `:md` `Node`s using [`MarkdownFormat`](#).
Parsd code cells have the following structure:

```julia
Node(:codecell,
    Node(:codeblock, _)  # source code
    Node(:codeoutput, _)  # printed output
    Node(:coderesult, _)  # return value of cell
)
```
"""
struct JupyterFormat <: Format end

extensionformat(::Val{:ipynb}) = JupyterFormat()


function parse(io::IO, format::JupyterFormat)
    return parse(JSON3.read(io), format)
end


function parse(data::JSON3.Object, format::JupyterFormat)
    attrs = merge(
        Dict(data[:metadata]),
        Dict(:nbformat => (data[:nbformat], data[:nbformat_minor]))
    )
    #=
    cs = XTree[]
    lang = get(get(get(obj, :metadata, Dict()), :language_info, Dict()), :name, "")
    for cell in obj[:cells]
        cs = vcat(cs, children(parsejupytercell(cell, lang)))
    end
    =#
    return Node(
        :jupyter,
        [parsejupytercell(cell, attrs) for cell in data[:cells]],
        attrs,
    )
end



parsejupytercell(cell, nbattrs) =
    parsejupytercell(cell, nbattrs, Val(Symbol(cell[:cell_type])))


function parsejupytercell(cell, nbattrs, ::Val{:markdown})
    return withattributes(
        parse(join(cell[:source], "\n"), MarkdownFormat()),
        merge(cell[:metadata], Dict(:id => get(cell, :id, nothing)))
    )
end

function parsejupytercell(cell, nbattrs, ::Val{:code})
    code = join(cell[:source])
    codeblock = Node(:codeinput, Node(:codeblock, code; lang = nbattrs[:kernelspec][:language]))
    chs = XTree[codeblock]


    return Node(
        :codecell, [
            codeblock,
            _parsecelloutputs(cell[:outputs])...
        ],
        merge(
            Dict(cell[:metadata]),
            Dict(
                :id => get(cell, :id, nothing),
                :execution_count => cell[:execution_count],
            )
        )
    )


end


function _parsecelloutputs(outputs)
    cs = Node[]
    stream = ""
    for output in outputs
        if output[:output_type] == "stream"
            stream *= join(output[:text])
        elseif output[:output_type] == "execute_result"
            # Add concatenated outputs first
            if !isempty(stream)
                push!(cs, Node(:codeoutput, Node(:codeblock, ANSI(stream))))
                stream = ""
            end

            # The handle result
            reprs = Dict(MIME(k) => join(v) for (k, v) in output[:data])
            if length(reprs) == 1 && first(keys(reprs)) == MIME("text/plain")
                push!(cs, Node(:coderesult, Node(:codeblock, ANSI(first(values(reprs))))))
            else
                push!(cs, Node(:coderesult, PreRendered(reprs)))
            end
        end
    end
    if stream != ""
        push!(cs, Node(:codeoutput, Node(:codeblock, ANSI(stream))))
    end
    return cs
end


#dict(x::Leaf{PreRendered}) = Dict(:mimes => x[].reprs)
