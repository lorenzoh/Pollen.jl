
struct Assets <: Rewriter
    srcpaths::Vector{<:AbstractPath}
    dstpaths::Vector{<:AbstractPath}
    isdirty::BitVector
end


function Assets(dir::AbstractPath; kwargs...)
    @assert isdir(dir)
    relativepaths = [relative(path(f), dir) for f in files(FileTree(dir))]
    return Assets(paths; kwargs...)
end

function Assets(paths; assetdir = p"assets/")
    srcpaths = AbstractPath[absolute(p) for p in paths]
    dstpaths = AbstractPath[joinpath(assetdir, p) for p in paths]
    isdirty = trues(length(srcpaths))
    return Assets(srcpaths, dstpaths, isdirty)
end


function postbuild(assets::Assets, project, dst, format)
    for i in 1:length(assets.srcpaths)
        if assets.isdirty[i]
            mkpath(joinpath(dst, parent(assets.dstpaths[i])))
            cp(assets.srcpaths[i], joinpath(dst, assets.dstpaths[1]), force = true)
            assets.isdirty[i] = false
        end
    end
end


function getfilehandlers(assets::Assets, project, srcdir, dst, format)
    return [(absolute(assetpath), () -> (assets.isdirty[i] = true;))
            for (i, assetpath) in enumerate(assets.srcpaths)]
end
