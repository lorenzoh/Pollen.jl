const ASSETS_DEFAULT_EXTENSIONS = [
    "jpg", "svg", "png", "bib", "css"
]

"""
    CopyAssets(; paths = ["*"], dir = "", extensions) <: Rewriters

Rewriter that copies asset files.

See `Pollen.ASSETS_DEFAULT_EXTENSIONS` for the default extensions
"""
Base.@kwdef struct CopyAssets <: Rewriter
    # Absolute path to directory in which to find assets
    dir::String
    # Glob paths to include
    paths = String["*"]
    # Extensions of files that should be copied
    extensions = ASSETS_DEFAULT_EXTENSIONS
    # Directory relative to build directory that assets are copied to
    outdir = ""
end

CopyAssets(dir; kwargs...) = CopyAssets(; dir=dir, kwargs...)

# TODO: add watcher that checks directories for new/updated files

function Pollen.postbuild(rewriter::CopyAssets, project, builder::FileBuilder)
    for path in matching_paths(rewriter.dir, rewriter.paths, rewriter.extensions)
        outfile = joinpath(string(builder.dir), rewriter.outdir, path)
        outdir = abspath(joinpath(outfile, ".."))
        isdir(outdir) || mkpath(outdir)
        cp(joinpath(rewriter.dir, path), outfile, force=true)
    end
end

function matching_paths(dir, patterns, extensions)
    paths = String[]
    for pattern in patterns
        for path in rglob(pattern, dir)
            if any([endswith(path, ext) for ext in extensions])
                push!(paths, relpath(path, dir))
            end
        end
    end
    return paths
end
