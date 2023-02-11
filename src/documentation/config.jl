
#=
This file defines the configuration for documentation projects.

- [`default_config`](#) defines a default configuration
- [`default_config`](#) defines a default configuration


- [`load_docs_config`](#) loads all applicable configurations and merges them
=#

#= ## Default config

The default configuration contains default values for many configuration
options. It also takes an ordered list of rewriter configurations so that
rewriters' default values can be loaded as well.


=#

function default_config()
    return Dict(
        "title" => "TITLE",
        "tag" => "dev",
        "package" => nothing,
        "rewriters" => Dict(
            "backlinks" => true,
            "sourcefiles" => true,
            "reference" => true,
            "parsecode" => true,
            "runcode" => false,
            "assets" => true,
        "documenter" => false,
        ),
        "frontend" => "files",
        "project" => ".",
        "contents" => Dict(),
    )
end

# To provide some better defaults for configuration like the project title, we can
# load a package's `Project.toml` file to extract some additional information.

function load_package_config(pkgdir::String; tag = nothing)
    projectconfig = TOML.parsefile(joinpath(pkgdir, "Project.toml"))
    tag = isnothing(tag) ? projectconfig["version"] : tag
    pkgid = "$(projectconfig["name"])@$tag"
    # TODO: if docs/Project.toml exists, set "project" => "./docs"
    return Dict(
        "title" => projectconfig["name"] * ".jl",
        "tag" => tag,
        "package" => Dict(
            "name" => projectconfig["name"],
            "version" => tag,
            "id" => pkgid,
            "dir" => pkgdir,
        ),
        "contents" => Dict(
            "README" => "$pkgid/doc/README.md",
        ),
    )
end

#=
## Rewriter configuration

The configuration also lets us configure which `Rewriter`s are used. The `Rewriter`
interface has a function that creates an instance from a configuration dict:
[`from_config`](#). We'll use this to instantiate the rewriters later.

The rewriter-specific configuration is under the `"rewriters"` key of the top-level project
configuration. To be able to use it to create our project's rewriters, we need to define a
list of rewriter configurations with

- (1) A mapping from configuration keys to `Rewriter` type (e.g. `("parsecode", ParseCode)`);
- (2) An ordering of rewriters: since some rewriters depend on each other either by the way
    they transform individual documents or the state they create, we need to make sure they
    have an ordering.
- (3) A default configuration value: this can be a simple `true/false` for enabled/disabled,
    or concrete configuration options that are passed to [`from_config`](#).
- (4) Dependencies on other rewriters.

This list of rewriter configurations has a default, but can be overwritten in code, if you
want to enable additional rewriters or replace existing ones. Additionally, frontends can
modify this list (in most cases to add additional, frontend-specific rewriters).
=#

Base.@kwdef struct RewriterConfig
    # Name of the configuration key
    key::String
    # Type of the Rewriter (not an instance)
    rewriter::Any
    # Default value with higher precendence than `default_config(Rewriter)`
    default::Any
    # Keys of previous rewriters that this depends on
    dependencies::Vector{String}
end

const DEFAULT_REWRITER_CONFIGS = RewriterConfig[
    # FIXME: create IndexPackages rewriter and use it here
    RewriterConfig("index", DocumentationFiles, true, []),
    RewriterConfig("documents", DocumentationFiles, true, []),
    RewriterConfig("sourcefiles", SourceFiles, true, ["index"]),
    RewriterConfig("references", ModuleReference, true, ["index"]),
    RewriterConfig("documenter", DocumenterCompat, false, ),
    RewriterConfig("parsecode", ParseCode, true),
    RewriterConfig("resolvesymbols", ResolveSymbols, true, ["parsecode"]),
    RewriterConfig("resolverefs", ResolveReferences, true),
    RewriterConfig("runcode", ExecuteCode, false, ["parsecode"]),
    RewriterConfig("backlinks", Backlinks, false, ["resolvesymbols"]),
    RewriterConfig("assets", Backlinks, false, ["resolvesymbols"]),

]

function load_rewriter_config()

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

function merge_configs(dst::Dict, src::Dict)
    out = Dict{Any, Any}(dst)
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

function merge_configs(dst::Dict, src::Dict, args...)
    cfg = merge_configs(dst, src)
    merge_configs(cfg, args...)
end

merge_configs(dst::Bool, src::Dict) = src
merge_configs(dst::Bool, src::Bool) = src
merge_configs(dst::Dict, src::Bool) = src ? dst : nothing


# TODO: handle merging `Bool`s

#= ## Loading configuration

To load a complete project configuration for a docs project in `dir`, we combine the
following configs in [`load_docs_config`](#):

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

# TODO: add `rewriters = DEFAULT_REWRITERS` and pass it to `default_config`
# TODO: populate rewriters with default config?
function load_docs_config(dir::String; tag = nothing)
    config = default_config()

    # Load package config
    if isfile(joinpath(dir, "Project.toml"))
        config = merge_configs(config, load_package_config(dir))
        # Load Documenter.jl config
        if isdocumenterproject(dir)
            config = merge_configs(config, load_documenter_config(dir, config["package"]))
        end
    end

    # Load pollen.yml config
    if isfile(joinpath(dir, "pollen.yml"))
        config = merge_configs(config, YAML.load_file(joinpath(dir, "pollen.yml")))
    end

    # Load frontend config
    if get(config, "frontend", nothing) !== nothing
        frontend = config["frontend"]
        config[frontend] = merge_configs(
            default_frontend_config(FRONTENDS[frontend]),
            get(config, frontend, Dict()))
    end

    # Load rewriter config
    rewriters = with_frontend_rewriters(FRONTENDS[frontend], rewriters)
    config["rewriters"] = merge_configs(
        get(config, "rewriters", Dict()),
        load_rewriter_config(rewriters))

    return config
end

# ## Utilities

@testset "load_docs_config" begin
    @test_nowarn load_docs_config(pkgdir(Pollen))
end
