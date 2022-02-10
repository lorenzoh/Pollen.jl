
struct LoadFrontendConfig <: Rewriter
    config::Dict{String,Any}
    dstpath::Any
end


function LoadFrontendConfig(path::Union{String,AbstractPath}, dstpath = "config.json")
    file = joinpath(path, "Project.toml")
    isfile(file) || throw(SystemError("loading conifg: \"$file\": No such file"))
    projectconfig = TOML.parsefile(file)
    config = if haskey(projectconfig, "pollen")
        merge(loaddefaults(projectconfig), projectconfig["pollen"])
    else
        @warn "No configuration section for Pollen found in \"$file\", using default values"
        DEFAULT_FRONTEND_CONFIG
    end

    tocfile = joinpath(path, "docs/toc.json")
    if isfile(tocfile)
        open(tocfile, "r") do f
            config["linktree"] = JSON3.read(f)
        end
    else
        config["linktree"] = defaulttoc(config)
    end
    return LoadFrontendConfig(config, dstpath)
end


function postbuild(rewriter::LoadFrontendConfig, _, builder::FileBuilder)
    dst = joinpath(builder.dir, rewriter.dstpath)
    open(dst, "w") do f
        JSON3.write(f, rewriter.config)
    end
end


function loaddefaults(project::Dict)
    return Dict(
        "title" => project["name"],
        "defaultDocument" => "documents/README.md",
        "viewerWidth" => 650,
    )
end
