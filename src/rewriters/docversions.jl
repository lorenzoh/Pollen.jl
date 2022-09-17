
struct DocVersions <: Rewriter
    pkgdir::String
    version::String
    config::Dict{String, Any}
end

# TODO: add file watcher that reloads the link tree
# TODO: add dependencies with their versions

DocVersions(m::Module; kwargs...) = DocVersions(pkgdir(m); kwargs...)
function DocVersions(pkgdir::String; tag = nothing, dependencies = String[])
    projectfile = joinpath(pkgdir, "Project.toml")
    isfile(projectfile) || throw(SystemError("loading config: \"$file\": No such file"))
    projectconfig = TOML.parsefile(projectfile)
    pollenconfig = get(projectconfig, "pollen", Dict())
    config = merge(loaddefaults(projectconfig), pollenconfig)
    config["dependencies"] = dependencies
    config["linktree"] = loadtoc(pkgdir, projectconfig)
    v = VersionNumber(projectconfig["version"])
    if !isnothing(tag)
        v = VersionNumber(v.major, v.minor, v.patch, (tag,), v.build)
    end

    return DocVersions(pkgdir, tag, config)
end

function postbuild(rewriter::DocVersions, _, builder::FileBuilder)
    dst = joinpath(builder.dir, "versions.json")
    versions = if isfile(dst)
        open(dst, "r") do f
            Dict(JSON3.read(f))
        end
    else
        Dict{Symbol, Any}()
    end
    versions[Symbol(rewriter.version)] = rewriter.config

    open(dst, "w") do f
        JSON3.write(f, versions)
    end
end

function loaddefaults(project::Dict)
    return Dict("title" => project["name"],
                "defaultDocument" => "documents/README.md",
                "columnWidth" => 650)
end

function loadtoc(pkgdir::String, projectconfig::Dict)
    tocfile = joinpath(pkgdir, "docs/toc.json")
    if isfile(tocfile)
        open(tocfile, "r") do f
            return JSON3.read(f)
        end
    else
        return defaulttoc(projectconfig)
    end
end

function defaulttoc(projectconfig)
    return OrderedDict("Overview" => "$(projectconfig["name"])@stable/doc/README.md",
                       "Reference" => Dict("Module" => "references/$(projectconfig["name"])"))
end
