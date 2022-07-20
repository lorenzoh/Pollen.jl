struct SaveAttributes <: Rewriter
    path::Any
    keys::Any
    useoutputs::Bool
end
function SaveAttributes(keys = nothing;
                        path = "attributes.json",
                        useoutputs = true)
    SaveAttributes(Path(path), keys, useoutputs)
end

function postbuild(save::SaveAttributes, project, builder::FileBuilder)
    attrs = Dict{String, Dict}()
    for (p, doc) in (save.useoutputs ? project.outputs : project.sources)
        a::Dict = attributes(doc)
        ks = isnothing(save.keys) ? keys(a) : save.keys
        d = Dict{Symbol, Any}()
        for k in ks
            if k isa Pair
                k, default = k
                d[k] = get(a, k, default)
            else
                d[k] = get(a, k, nothing)
            end
        end
        d[:tag] = tag(doc)
        attrs[string(p)] = d
    end

    dst = joinpath(builder.dir, save.path)
    open(dst, "w") do f
        JSON3.write(f, attrs)
    end
end
