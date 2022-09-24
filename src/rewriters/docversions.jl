
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
    tag = isnothing(tag) ? string(projectconfig["version"]) : tag
    pkgid = "$(projectconfig["name"])@$tag"

    config = merge(loaddefaults(projectconfig, pkgid), pollenconfig)
    config["dependencies"] = dependencies
    config["linktree"] = loadtoc(pkgdir, projectconfig, pkgid)
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

function loaddefaults(project::Dict, pkgid)
    return Dict("title" => project["name"],
                "defaultDocument" => "$pkgid/doc/README.md",
                "columnWidth" => 650)
end

function loadtoc(pkgdir::String, projectconfig::Dict, pkgid)
    tocfile = joinpath(pkgdir, "docs/toc.json")
    tree = if isfile(tocfile)
        open(tocfile, "r") do f
            JSON3.read(f)
        end
    else
        defaulttoc(projectconfig, pkgid)
    end
    __mapdictleaves(tree) do link
        linkinfo = LinkInfo(string(link), "", "$pkgid/doc/index.md", Node(:no), "", pkgid, projectconfig["name"])
        parselink(InternalLinkRule(), linkinfo)
    end
end


__mapdictleaves(f, d::Union{<:Dict, <:JSON3.Object}) = OrderedDict(map((k, v) -> (k => __mapdictleaves(f, v)), keys(d), values(d)))
__mapdictleaves(f, x) = f(x)

function defaulttoc(projectconfig, pkgid)
    return OrderedDict("Overview" => "$pkgid/doc/README.md",
                       "Reference" => Dict("Module" => "$pkgid/ref/$(projectconfig["name"])"))
end
