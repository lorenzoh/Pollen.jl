
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
    for (i, (dstpath, srcpath)) in enumerate(assets.assets)
        if assets.isdirty[i]
            mkpath(joinpath(builder.dir, parent(dstpath)))
            cp(srcpath, joinpath(builder.dir, dstpath), force = true)
            assets.isdirty[i] = false
        end
    end
end
function postbuild(assets::Assets, project, builder::Builder)
    error("`Assets` does not work with $builder")
end


function getfilehandlers(assets::Assets, project, dir, builder)
    return [(srcpath, () -> (assets.isdirty[i] = true;))
            for (i, srcpath) in enumerate(values(assets.assets))]
end


function reset!(assets::Assets)
    fill!(assets.isdirty, true)
end
