
struct Assets <: Rewriter
    # Mapping of asset name (virtual path) to physical path
    assets::OrderedDict{AbstractPath, AbstractPath}
    isdirty::BitVector
end


function Assets(srcdir::AbstractPath; kwargs...)
    @assert isdir(srcdir)
    return Assets(srcdir, [relative(p, srcdir) for p in walkpath(srcdir)]; kwargs...)
end

function Assets(srcdir::AbstractPath, paths::AbstractVector{<:AbstractPath}; dstdir = p"assets/")
    assets = Dict(joinpath(dstdir, p) => absolute(joinpath(srcdir, p)) for p in paths)
    return Assets(assets)
end

function Assets(assets::Dict)
    isdirty = trues(length(assets))
    return Assets(assets, isdirty)
end


function postbuild(assets::Assets, project, builder::FileBuilder)
    for (i, (relp, srcpath)) in enumerate(assets.assets)
        dstpath = joinpath(builder.dir, relp)
        if !isfile(dstpath)
            mkpath(joinpath(builder.dir, parent(dstpath)))
            cp(srcpath, dstpath, force = true)
            assets.isdirty[i] = false
        end
    end
end


function filehandlers(assets::Assets, project, builder::FileBuilder)
    handlers = Dict()
    for (relp, fp) in assets.assets
        handlers[fp] = () -> cp(fp, joinpath(builder.dir, relp); force = true)
    end
    return handlers
end


function reset!(assets::Assets)
    fill!(assets.isdirty, true)
end
