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

    attrss = Dict{String, Dict}()

    for (id, doc) in (save.useoutputs ? project.outputs : project.sources)
        pkg = first(splitpath(id))
        attrs = get!(attrss, pkg, Dict{String, Dict}())
        ks = isnothing(save.keys) ? keys(a) : save.keys
        a = attributes(doc)
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
        attrs[id] = d
    end

    for (pkg, attrs) in attrss
        dst = joinpath(builder.dir, pkg, "index.json")
        open(dst, "w") do f
            JSON3.write(f, attrs)
        end
    end
    return
end
