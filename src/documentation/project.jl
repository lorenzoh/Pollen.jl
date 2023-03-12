#=

This file contains high-level functionality for creating [`Project`](#)s for creating
documentation.

- [`load_project`](#) creates a [`Project`](#) for package documentation. It takes care
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

# TODO: allow overwriting frontend directly
function load_project(
        dir::Union{Nothing, String} = nothing;
        config = Dict{String, Any}(),
        rewriter_entries=DEFAULT_REWRITER_ENTRIES,
        )::Project
    config::ConfigProject = load_project_config(dir; extra_config=config, rewriter_entries)
    from_config(config)
end

load_project(mod::Module; kwargs...) = load_project(pkgdir(mod); kwargs...)




function build_project(
        project::Project;
        dir = mktempdir(),
        docids = Set(keys(project.sources)))
    isnothing(project.frontend) && throw(ArgumentError("Project must have a frontend to build!"))
    julia_project = if isnothing(project.config.package)
        Base.active_project()
    else
        project.config.project
    end
    ModuleInfo.with_project(julia_project) do
        @info "Rewriting documents..."
        rewritesources!(project, docids)
    end

    @info "Building pages..." dir
    frontend_build(project.frontend, project, dir, docids)
    return project
end

function build_project(
        project_dir::Union{Nothing, String} = nothing;
        config = Dict{String, Any}(),
        rewriter_entries=DEFAULT_REWRITER_ENTRIES,
        kwargs...)
    build_project(load_project(project_dir; config, rewriter_entries))
end



# TODO: Fix
function serve_project(pkg, frontend, config; tag = nothing, lazy = false, dir = mktempdir())
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


# ## Helpers

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