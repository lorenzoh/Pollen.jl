
#=
This file defines the configuration for documentation projects.

- [`default_config`](#) defines a default configuration
- [`default_config`](#) defines a default configuration


- [`load_project_config`](#) loads all applicable configurations and merges them
=#

#= ## Project configuration

The default configuration contains default values for many configuration
options. It also takes an ordered list of rewriter configurations so that
rewriters' default values can be loaded as well.

=#

function from_project_config(C::Type{<:AbstractConfig}, config_project::ConfigProject, values::Dict = Dict{String, Any}())
    C(;
        #Dict(name => from_project_config(T,ll_project, Configurations.field_default(C, name))
        Dict(name => from_project_config(T, config_project, get(values, string(name), Dict{String, Any}()))
            for (name, T) in zip(fieldnames(C), fieldtypes(C)) if T <: AbstractConfig)...)


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


function load_frontend_config(project_config::ConfigProject)
    isnothing(project_config.frontend) && return
    haskey(project_config.frontend, "type") || return

    # We find the type of the frontend and its corresponding config type
    FrontendType = FRONTENDS[project_config.frontend["type"]]
    FrontendConfigType = configtype(FrontendType)

    # Then create a default config and update it with any values explicitly configured
    values = copy(project_config.frontend)
    delete!(values, "type")
    return from_project_config(FrontendConfigType, project_config, values)
end


Base.@kwdef struct RewriterEntry
    # Name of the configuration key
    key::String
    # Type of the Rewriter (not an instance)
    rewritertype::Any
    # Enabled by default
    enabled::Bool = true
    # Keys of previous rewriters that this depends on
    dependencies::Vector{String}
    # Default value with higher precendence than `default_config(Rewriter)`
    defaults::Dict = Dict{String, Any}()
end

const DEFAULT_REWRITER_ENTRIES = RewriterEntry[
    RewriterEntry("documents", DocumentationFiles, true, [], Dict{String, Any}()),
    RewriterEntry("sourcefiles", SourceFiles, true, [], Dict{String, Any}()),
    RewriterEntry("references", ModuleReference, true, [], Dict{String, Any}()),
    RewriterEntry("documenter", DocumenterCompat, false, [], Dict{String, Any}()),
    RewriterEntry("parsecode", ParseCode, true, [], Dict{String, Any}()),
    RewriterEntry("resolvesymbols", ResolveSymbols, true, ["parsecode"], Dict{String, Any}()),
    RewriterEntry("resolverefs", ResolveReferences, true, [], Dict{String, Any}()),
    RewriterEntry("runcode", ExecuteCode, false, ["parsecode"], Dict{String, Any}()),
    RewriterEntry("backlinks", Backlinks, true, ["resolverefs"], Dict{String, Any}()),
]

function load_rewriter_configs(
        project_config::ConfigProject,
        rewriter_entries::Vector{RewriterEntry} = DEFAULT_REWRITER_ENTRIES)
    # TODO: use project config to load
    rewriter_configs = AbstractConfig[]
    keys = Set{String}()
    for entry in rewriter_entries
        # If disabled by default and no explicit configuration, don't include the rewriter
        (entry.enabled || haskey(project_config.rewriters, entry.key)) || continue

        # TODO: use entry.defaults
        config_value = get(project_config.rewriters, entry.key, entry.enabled)
        if config_value isa Bool
            # Don't include rewriter if it is not enabled by default or the config set to
            # `false` explicitly
            config_value || continue
            # If enabled by default or explicitly without parameters
            config_value = Dict{String, Any}()
        end

        # Check all dependency rewriters are already in the list
        for dep in entry.dependencies
            dep in keys || throw(ArgumentError("""
                When loading config for rewriter $(entry.rewritertype) with key $(entry.key),
                expected depdency rewriter $dep to be loaded, but so far have only rewriters
                $keys are loaded!"""))
        end

        # Finally create the configuration and keep track of it
        rewriter_config = from_project_config(
            configtype(entry.rewritertype), project_config, config_value)

        push!(rewriter_configs, rewriter_config)
        push!(keys, entry.key)
    end
    return rewriter_configs
end


function resolve_content_links(contents::Dict)

end


#=
## Merging configurations

[`merge_configs`](#) allows us to combine configs (`Dict`s) with differing precedence
recursively.
The first argument has lower precedence, its keys being overwritten by those in the second.

One special case to handle is where one or both of the configs are actually Boolean values.
A Boolean value of `false` means a configuration value should be set to `nothing`, while
`true` means the default configuration should be used. See the code for the exact semantics.
 TODO: Update section
=#


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

function load_project_config(
        dir::Union{String, Nothing};
        extra_config = Dict{String, Any}(),
        rewriter_entries = DEFAULT_REWRITER_ENTRIES)
    config = ConfigProject()

    # Load package config
    if !isnothing(dir) && isfile(joinpath(dir, "Project.toml"))
        config = merge_configs(config, load_package_config(dir))
        # Load Documenter.jl config
        if isdocumenterproject(dir)
            config = merge_configs(config, load_documenter_config(config.package))
        end
    end

    # Load pollen.yml config
    if !isnothing(dir) && isfile(joinpath(dir, "pollen.yml"))
        yaml_config = YAML.load_file(joinpath(dir, "pollen.yml"); dicttype=Dict{String, Any})
        config = merge_configs(config, yaml_config)
    end

    config = merge_configs(config, extra_config)

    if !isnothing(config.package)
        config = merge_configs(config, Dict("contents" => resolve_toc(config.contents, config.package.name, "")))
    end

    # Load frontend config
    config = merge_configs(
        config,
        Dict("config_frontend" => load_frontend_config(config)))

    # Load rewriter configs
    # TODO: maybe use frontend config to change rewriter entries?
    rewriter_entries = with_frontend_rewriters(config.config_frontend, rewriter_entries)
    config = merge_configs(
        config,
        Dict("configs_rewriter" => load_rewriter_configs(config, rewriter_entries)))

    return config
end


load_project_config(mod::Module) = load_project_config(pkgdir(mod))

# ## Utilities

@testset "Project configuration" begin
    @testset "load_package_config" begin
        pkg_config = load_package_config(pkgdir(@__MODULE__))
        @test_nowarn from_dict(ConfigProject, pkg_config)
        @test all(in(keys(pkg_config)).(["title", "package", "contents"]))
        @test all(in(keys(pkg_config["package"])).(["dir", "version", "name"]))
        @test all(in(keys(pkg_config["contents"])).(["README", "Reference"]))
    end
    @testset "load_project_config" begin
        @testset "Pollen (package with pollen.yml)" begin
            config = load_project_config(pkgdir(Pollen))
            @test config.project == "./docs"
            @test config.title == "Pollen.jl"
            @test !isnothing(config.package)
        end
        @testset "Pollen (package with Documenter.jl setup)" begin
            config = load_project_config(pkgdir(AbstractTrees))
            @test config.title == "AbstractTrees.jl"
            @test config.project == "./docs"
            @test length(keys(config.contents)) >= 2
            @test config.package.name == "AbstractTrees"
            @test any(rc -> rc isa ConfigDocumenterCompat, config.configs_rewriter)
        end
    end
end
