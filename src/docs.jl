"""
    servedocs(m::Module)
    servedocs(pkgdir)

Serve the documentation for a package.

Will fail if the documentation is not set up properly.
"""
function servedocs(
        encm::Module,
        pkgdir::String;
        subdir = "docs",
        lazy = get(ENV, "POLLEN_LAZY", "false") == "true",
        port = Base.parse(Int, get(ENV, "POLLEN_PORT", "8000")),
        kwargs...)
    try validatedocs(pkgdir; subdir) catch e
        @error "Failed to detect a proper documentation setup for package directory \"$pkgdir\""
        rethrow()
    end
    PkgTemplates.with_project(joinpath(pkgdir, subdir)) do
        @info "Loading project configuration"
        project = Base.include(encm, joinpath(pkgdir, subdir, "project.jl"))
        Pollen.serve(
            project;
            lazy,
            port,
            kwargs...

        )

    end

end


servedocs(encm::Module, pkg::Module, args...; kwargs...) = servedocs(encm, Pkg.pkgdir(pkg), args...; kwargs...)


"""
    validatedocs(m::Module)
    validatedocs(pkgdir)
"""
function validatedocs(pkgdir::String; subdir = "docs")
    isdir(pkgdir) || throw(ArgumentError("Could not find package directory \"$pkgdir\""))
    docsdir = joinpath(pkgdir, subdir)
    isdir(docsdir) || throw(ArgumentError("Could not find documentation folder in package directory at "))

    docs_project = joinpath(docsdir, "Project.toml")
    isfile(docs_project) || throw(ArgumentError("Could not find documentation project at \"$docs_project\""))
    project_config = TOML.parse(read(docs_project, String))
    "Pollen" ∈ keys(project_config["deps"]) || throw("Expected `Pollen` to be a dependency in documentation project at \"$docsdir\"")

    for f in ("project.jl", "make.jl", "toc.json", "serve.jl")
        isfile(joinpath(docsdir, f)) || throw(ArgumentError("Required file \"$f\" does not exist in documentation directory \"$docsdir\""))
    end
end

validatedocs(m::Module; kwargs...) = validatedocs(Pkg.pkgdir(m); kwargs...)

@testset "validatedocs" begin
    mktempdir() do dir
        @test_throws ArgumentError validatedocs(dir)
    end
end
