struct SaveAttributes <: Rewriter
    path::Any
    keys::Any
end
SaveAttributes(keys = nothing) = SaveAttributes(Path("attributes.json"), keys)


function postbuild(save::SaveAttributes, project, builder::FileBuilder)
    attrs = Dict{String,Dict}()
    for (p, doc) in project.outputs
        a::Dict = attributes(doc)
        ks = isnothing(save.keys) ? keys(a) : save.keys
        d = Dict{Symbol,Any}(k => a[k] for k in ks)
        d[:tag] = tag(doc)
        attrs[string(p)] = d
    end

    dst = joinpath(builder.dir, save.path)
    open(dst, "w") do f
        JSON3.write(f, attrs)
    end
end
