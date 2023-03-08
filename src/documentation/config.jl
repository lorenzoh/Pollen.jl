
#=
This file defines the configuration for documentation projects.

- [`default_config`](#) defines a default configuration
- [`default_config`](#) defines a default configuration


- [`load_project_config`](#) loads all applicable configurations and merges them
=#

#= ## Default config

The default configuration contains default values for many configuration
options. It also takes an ordered list of rewriter configurations so that
rewriters' default values can be loaded as well.


=#

function default_config()
    return Dict{String, Any}(
        "title" => "TITLE",
        "tag" => "dev",
        "rewriters" => Dict{String, Any}(),
        "frontend" => "files",
        "project" => ".",
        "contents" => Dict(),
    )
end

# To provide some better defaults for configuration like the project title, we can
# load a package's `Project.toml` file to extract some additional information.

"""
    load_package_config(dir)

Load package-specific configuration defaults from a Pollen project directory `dir`.
This is only called if `dir` is a Julia package, i.e. contains a `Project.toml` file.
"""
function load_package_config(dir::String)
    projectconfig = TOML.parsefile(joinpath(dir, "Project.toml"))
    pkg_config = Dict{String, Any}(
        "title" => projectconfig["name"] * ".jl",
        "package" => Dict(
            "name" => projectconfig["name"],
            "version" => projectconfig["version"],
            "uuid" => projectconfig["uuid"],
            "authors" => get(projectconfig, "authors", String[]),
            "dir" => dir,
        ),
        "contents" => Dict(
            "README" => "doc/$(projectconfig["name"])/README.md",
            "Reference" => "ref/$(projectconfig["name"])",
        ),
    )
    if isfile(joinpath(dir, "docs", "Project.toml"))
        pkg_config["dir"] = "./docs"
    end
    return pkg_config
end


#=
## Merging configurations

[`merge_configs`](#) allows us to combine configs (`Dict`s) with differing precedence
recursiveley.
The first argument has lower precedence, its keys being overwritten by those in the second.

One special case to handle is where one or both of the configs are actually Boolean values.
A Boolean value of `false` means a configuration value should be set to `nothing`, while
`true` means the default configuration should be used. See the code for the exact semantics.
=#

function merge_configs(dst::Dict{T}, src::Dict{T2}) where {T, T2}
    out = Dict{T === T2 ? T : Any, Any}(dst)
    for k in keys(src)
        if src[k] isa Dict
            if get(dst, k, nothing) isa Dict
                out[k] = merge_configs(dst[k], src[k])
            else
                out[k] = src[k]
            end
        else
            out[k] = src[k]
        end
    end
    return out
end

merge_configs(dst::Bool, src::Dict) = src
merge_configs(dst::Bool, src::Bool) = src
merge_configs(dst::Dict, src::Bool) = src ? dst : false


#= ## Loading configuration

To load a complete project configuration for a Pollen project in `dir`, we combine the
following configs in [`load_project_config`](#):

- the default config ([`default_config`](#))
- IF `dir` contains a `Project.toml`, the package config (with [`load_package_config`](#))
- IF `dir` has a `docs/` subfolder with a Documenter.jl setup, the Documenter configuration
    (see [`documenter.jl`](./documenter.jl))
- IF `dir` contains a `pollen.yml`, load configuration from it (by parsing the YAML)

These configurations are then merged with lowest to highest precedence.

Finally, the "frontend" key in the configuration is used to determine which frontend
should be used. The default configuration for the frontend is then merged with
existing frontend entries in the config.
=#

function load_project_config(dir::Union{String, Nothing})
    config = default_config()

    # Load package config
    if !isnothing(dir) && isfile(joinpath(dir, "Project.toml"))
        config = merge_configs(config, load_package_config(dir))
        # Load Documenter.jl config
        if isdocumenterproject(dir)
            config = merge_configs(config, load_documenter_config(dir, config["package"]))
        end
    end

    # Load pollen.yml config
    if !isnothing(dir) && isfile(joinpath(dir, "pollen.yml"))
        config = merge_configs(config, YAML.load_file(joinpath(dir, "pollen.yml"); dicttype=Dict{String, Any}))
    end

    # Load frontend config
    if get(config, "frontend", nothing) !== nothing
        frontend = config["frontend"]
        config[frontend] = merge_configs(
            default_config(FRONTENDS[frontend]),
            get(config, frontend, Dict()))
    end

    # Maybe do this in load_rewriters??
    # Load rewriter config
    #=
    rewriter_configs = with_frontend_rewriters(FRONTENDS[frontend], rewriter_configs)
    config["rewriters"] = merge_configs(
        get(config, "rewriters", true),
        load_rewriter_config(rewriter_configs))
    =#

    return config
end

load_project_config(mod::Module) = load_project_config(pkgdir(mod))

# ## Utilities

@testset "Project configuration" begin
    @testset "default_config" begin
        config = default_config()
        @show keys(config)
        @test all(in(keys(config)).(["title", "project", "contents", "frontend"]))
    end
    @testset "load_package_config" begin
        pkg_config = load_package_config(pkgdir(@__MODULE__))
        @test all(in(keys(pkg_config)).(["title", "package", "contents"]))
        @test all(in(keys(pkg_config["package"])).(["dir", "version", "name"]))
        @test all(in(keys(pkg_config["contents"])).(["README", "Reference"]))
    end
    @testset "load_project_config" begin
        @testset "Pollen (package with pollen.yml)" begin
            config = load_project_config(pkgdir(Pollen))
            @test config["project"] == "./docs"
            @test config["title"] == "Pollen.jl"
            @test haskey(config, "package")
        end
        @testset "Pollen (package with Documenter.jl setup)" begin
            config = load_project_config(pkgdir(AbstractTrees))
            YAML.write(config) |> println
            @test config["title"] == "AbstractTrees.jl"
            @test config["project"] == "./docs"
            @test length(keys(config["contents"])) >= 2
            @test config["package"]["name"] == "AbstractTrees"
            @test config["rewriters"]["documenter"] === true
        end
    end
end
