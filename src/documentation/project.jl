#=

This file contains high-level functionality for creating [`Project`](#)s for creating
documentation.

- [`docsproject`](#) creates a [`Project`](#) for package documentation. It takes care
    of loading configuration and creating rewriters based on it.
- [`builddocs`](#) builds the complete project to a directory using a frontend
- [`servedocs`](#) runs an interactive build of the proejct using a frontend
=#

#=
## `docsproject`

To create a [`Project`](#) for documentation, we

1. load the complete configuration (see [config.jl](./config.jl))
2. instantiate the frontend
3. collect rewriters based on the project and frontend configs
=#

function load_project(
        dir::Union{Nothing, String} = nothing;
        # Highest precedence configuration options
        config = true,
        frontend = nothing,
        rewriter_configs=DEFAULT_REWRITER_CONFIGS,
        )::Project
    config = merge_configs(load_project_config(dir), config)
    frontend = isnothing(frontend) ? load_project_frontend(config) : frontend
    rewriters, rconfig = project_rewriters(config, rewriter_configs, frontend)
    config["rewriters"] = rconfig
    return Project(rewriters, frontend, config)
end

load_project(mod::Module; kwargs...) = load_project(pkgdir(mod); kwargs...)


function load_project_frontend(project_config)::Union{Nothing, <:Frontend}
    frontend_key = get(project_config, "frontend", "files")
    frontend_config = get(project_config, frontend_key, Dict())
    return from_project_config(FRONTENDS[frontend_key], frontend_config, project_config)
end


function build_project(
    project_dir::Union{Nothing, String} = nothing;
    dir = mktempdir(),
    kwargs...
)
    project = load_project(project_dir; kwargs...)
    builder = frontend_builder(project.frontend, dir)
    ModuleInfo.with_project(get(project.config, "project", Base.active_project())) do
        @info "Rewriting documents..."
        rewritesources!(project)
    end
    @info "Building pages..." dir
    build(builder, project)
    return project
end


# TODO: rename/rewrite

function builddocs(pkg, frontend, config; tag = nothing, dir = mktempdir())
    project = PkgTemplates.with_project(joinpath(pkgdir(pkg), config["project"])) do
        @info "Loading project configuration..."
        project = docsproject(pkg, frontend, config; tag)
        @info "Rewriting documents..."
        rewritesources!(project)
        project
    end
    builder = frontend_builder(frontend, dir)
    @info "Building documentation site..."
    build(builder, project)
end


function builddocs(pkg::Module; frontend = nothing, config = nothing,
                   tag = nothing, dir = mktempdir())
    config, frontend = get_config_frontend(pkg; frontend, config, tag)
    builddocs(pkg, frontend, config; tag, dir)
end


function servedocs(pkg, frontend, config; tag = nothing, lazy = false, dir = mktempdir())
    project = PkgTemplates.with_project(joinpath(pkgdir(pkg), config["project"])) do
        @info "Loading project configuration..."
        project = docsproject(pkg, frontend, config; tag)
        @info "Rewriting documents..."
        lazy || rewritesources!(project)
        project
    end
    @info "Serving documentation site..."
    # TODO: run Pollen.jl server with update signals and Frontend-specific server
    # in parallel
    builder = frontend_builder(frontend, dir)
    server = Server(project, builder)
    runserver(server, lazy ? ServeFilesLazy() : ServeFiles())
end


function servedocs(pkg::Module; frontend = nothing, config = nothing,
                   tag = nothing, dir = mktempdir())
    config, frontend = get_config_frontend(pkg; frontend, config, tag)
    servedocs(pkg, frontend, config; tag, dir)
end


#=
## Project rewriters

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
    RewriterConfig("documents", DocumentationFiles, true, []),
    RewriterConfig("sourcefiles", SourceFiles, true, []),
    RewriterConfig("references", ModuleReference, true, []),
    RewriterConfig("documenter", DocumenterCompat, false, []),
    RewriterConfig("parsecode", ParseCode, true, []),
    RewriterConfig("resolvesymbols", ResolveSymbols, true, ["parsecode"]),
    RewriterConfig("resolverefs", ResolveReferences, true, []),
    RewriterConfig("runcode", ExecuteCode, false, ["parsecode"]),
    RewriterConfig("backlinks", Backlinks, true, ["resolverefs"]),
]

#=
function load_rewriters_config(rewriter_configs::Vector{RewriterConfig})
    config = Dict{String, Any}()
    for cfg in rewriter_configs
        # Check that all dependencies are already added.
        config[cfg.key] = cfg.default
    end
    return config
end
=#


# ## Helpers


"""
    project_rewriters(config, rewriter_configs::Vector{RewriterConfig}) -> Rewriter[]

Instantiate rewriters from the global project configuration `config` and
a list of rewriters to use.
"""
function project_rewriters(project_config, rewriter_configs::Vector = DEFAULT_REWRITER_CONFIGS)
    # TODO: check that all keys in config["rewriters"] are actual rewriters
    # TODO: check that there are no duplicate keys
    # and warn if not
    rewriters = Rewriter[]
    configs = Dict()
    rkeys = Set()
    for (; key, rewriter, dependencies, default) in rewriter_configs
        for dep in dependencies
            dep in rkeys || error("""
                Rewriter `$(cfg.rewriter)` with key `$(cfg.key)` depends on a rewriter
                with key `$dep` but that rewriter was not found. Make sure that in your
                `rewriter_configs` there is an entry with key `$dep` that comes before
                this rewriter `$(cfg.key)`!""")
        end

        rconfig = canonicalize_config(rewriter, merge_configs(
            default,
            canonicalize_config(rewriter, get(project_config["rewriters"], key, default))))

        rconfig = merge_configs(
            default_config_project(rewriter, project_config),
            rconfig)

        if rconfig !== false
            push!(rewriters, from_config(rewriter, rconfig))
            push!(rkeys, key)
        end
        configs[key] = rconfig
    end
    return rewriters, configs
end


# Helper version that incorporates frontend rewriters
function project_rewriters(config, rewriter_configs, frontend::Frontend)
    rewriter_configs = with_frontend_rewriters(frontend, rewriter_configs)
    project_rewriters(config, rewriter_configs)
end


function get_config_frontend(pkg; frontend = nothing, config = nothing, tag = nothing)
    # TODO: merge with kwarg config that has highest precedence
    config = isnothing(config) ? load_project_config(pkgdir(pkg); tag) : config
    frontend = isnothing(frontend) ? FRONTENDS[config["frontend"]](config) : frontend(config)
    return config, frontend
end

function with_project(f, projectdir; verbose = false)
    suppress(f) = verbose ? f() : IOCapture.capture(f)
    proj = Base.active_project()
    if !endswith(projectdir, "Project.toml")
        projectdir = joinpath(projectdir, "Project.toml")
    end
    if projectdir == proj
        f()
    else
        try
            suppress(() -> Pkg.activate(projectdir))
            f()
        finally
            suppress(() -> proj === nothing ? Pkg.activate() : Pkg.activate(proj))
        end
    end
end

@testset "baserewriters" begin
    @test_broken baserewriters(Pollen, default_config())
end
