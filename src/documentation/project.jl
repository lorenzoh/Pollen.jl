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
"""
    docsproject(pkg; frontend, config, tag)
"""
function docsproject(pkg::Module; frontend = nothing, config = nothing, tag = nothing)
    config, frontend = get_config_frontend(pkg; frontend, config, tag)
    return docsproject(pkg, frontend, config; tag)
end

function docsproject(pkg::Module, frontend, config; tag = nothing)
    rewriters = vcat(
        baserewriters(pkg, config; tag),
        frontend_rewriters(frontend))
    return Project(rewriters)
end


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


# ## Helpers

const DOCS_REWRITERS = [
    ("sourcefiles", SourceFiles)
]

function baserewriters(pkg, config; tag = nothing)
    # Prepare package index
    pkgtags = isnothing(tag) ? Dict() : Dict(string(pkg) => tag)
    pkgindex = PackageIndex([pkg]; pkgtags, verbose=true, cache=true, recurse=0)
    pkgid = "$(config["package"]["name"])@$(config["tag"])"

    rewriters = Rewriter[]
    push!(rewriters, DocumentationFiles([pkg]; pkgtags))
    c = config["rewriters"]
    c["sourcefiles"] && push!(rewriters, SourceFiles([pkg]; pkgtags))
    c["reference"] && push!(rewriters, ModuleReference(pkgindex))

    c["documenter"] && push!(rewriters, DocumenterCompat(pkgindex))
    if c["parsecode"] || c["runcode"]
        push!(rewriters, ParseCode())
        push!(rewriters, ResolveSymbols(pkgindex))
    end
    push!(rewriters, ResolveReferences(pkgindex))
    c["runcode"] && push!(rewriters, ExecuteCode())
    c["backlinks"] && push!(rewriters, Backlinks())
    c["assets"] && push!(rewriters, CopyAssets(config["package"]["dir"], outdir="$pkgid/doc"))

    return rewriters
end

function get_config_frontend(pkg; frontend = nothing, config = nothing, tag = nothing)
    # TODO: merge with kwarg config that has highest precedence
    config = isnothing(config) ? load_docs_config(pkgdir(pkg); tag) : config
    frontend = isnothing(frontend) ? FRONTENDS[config["frontend"]](config) : frontend(config)
    return config, frontend
end

function with_project(f, projectdir)
    proj = Base.active_project()
    if !endswith(projectdir, "Project.toml")
        projectdir = joinpath(projectdir, "Project.toml")
    end
    if projectdir == proj
        f()
    else
        try
            Pkg.activate(projectdir)
            f()
        finally
            proj === nothing ? Pkg.activate() : Pkg.activate(proj)
        end
    end
end

@testset "baserewriters" begin
    @test_nowarn baserewriters(Pollen, default_config())
end
