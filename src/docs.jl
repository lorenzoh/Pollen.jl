"""
    servedocs(m::Module)
    servedocs(pkgdir)

Serve the documentation for a package, assuming it is set up correctly. Will fail if
it is not. See [`PollenPlugin`](#) for more information about setup.

This starts two servers:

- a static file server that serves all rewritten documents with file extensions `format`,
    by default on port 8000
- a locally running frontend that gives a preview, at port 5173, if `frontend = true`

!!! note "Frontend installation"

    If `frontend=true` and `frontenddir` is not changed, the code for the frontend will be
    cloned and installed the first time you run `servedocs`.

## Keyword arguments

- `subdir = docs`: The subdirectory of `pkgdir` in which Pollen.jl documentation files
    are stored. Corresponds to [`PollenPlugin`](#)'s `folder` argument.
- `port = 8000`: The port on which the static file server runs. Can also be overwritten
    with the enviroment variable `"POLLEN_PORT"`.
- `lazy = true`: Whether to use lazy mode. In lazy mode, documents will only be rewritten
    once you open them in the frontend. This is useful when working on large projects,
    when you only want to see the preview of a few pages, without having to wait for all
    pages to build.
- `dir = mktempdir()`: The directory to which pages for the static file server are built.
- `tag = "dev"`: The version tag associated with this build. More relevant for deployment.
- `frontend = true`: Whether to run the frontend server.
- `frontenddir = Pollen.FRONTENDDIR`: Folder where frontend repository is looked for.
    If you want to develop on the frontend, overwrite this with your local version.
"""
function servedocs(pkgdir::String;
                   subdir = "docs",
                   lazy = get(ENV, "POLLEN_LAZY", "false") == "true",
                   port = Base.parse(Int, get(ENV, "POLLEN_PORT", "8000")),
                   tag = "dev",
                   dir = mktempdir(),
                   kwargs...)
    try
        validatedocs(pkgdir; subdir)
    catch e
        @error "Failed to detect a proper documentation setup for package directory \"$pkgdir\""
        rethrow()
    end
    docdir = joinpath(pkgdir, subdir)
    @info "Loading project configuration from $docdir"
    PkgTemplates.with_project(docdir) do
        m = Module(Symbol("$(splitpath(pkgdir)[end])Docs"))
        Base.include(m, joinpath(pkgdir, subdir, "project.jl"))
        project = Base.invokelatest(m.createproject, tag = tag)
        @info "Starting development server..."
        Pollen.serve(project, dir;
                     lazy,
                     port,
                     kwargs...)
    end
end

function servedocs(pkg::Module, args...; kwargs...)
    servedocs(Pkg.pkgdir(pkg), args...; kwargs...)
end

"""
    validatedocs(m::Module)
    validatedocs(pkgdir)
"""
function validatedocs(pkgdir::String; subdir = "docs")
    isdir(pkgdir) || throw(ArgumentError("Could not find package directory \"$pkgdir\""))
    docsdir = joinpath(pkgdir, subdir)
    isdir(docsdir) ||
        throw(ArgumentError("Could not find documentation folder in package directory at "))

    docs_project = joinpath(docsdir, "Project.toml")
    isfile(docs_project) ||
        throw(ArgumentError("Could not find documentation project at \"$docs_project\""))
    project_config = TOML.parse(read(docs_project, String))
    "Pollen" ∈ keys(project_config["deps"]) ||
        throw("Expected `Pollen` to be a dependency in documentation project at \"$docsdir\"")

    for f in ("project.jl", "make.jl", "toc.json")
        isfile(joinpath(docsdir, f)) ||
            throw(ArgumentError("Required file \"$f\" does not exist in documentation directory \"$docsdir\""))
    end
end

validatedocs(m::Module; kwargs...) = validatedocs(Pkg.pkgdir(m); kwargs...)

"""
    prerenderdocs(pkgdir; tag = "dev", env = Dict(), datadir = nothing, frontenddir = nothing)

Prerender the documentation frontend and return the folder with the files. That folder
can be put anywhere you can host static sites.

To build for GitHub Pages, use [`deploydocs`](#).

## Keyword arguments

- `tag = "dev"`: The version tag to be associated with the documentation build
- `env = Dict()`: Environment variables to set during frontend build
- `hostpath = nothing`: If the static files will not be deployed at the root level of a web
    server, set this to the corresponding subpath (without trailing slash). For example,
    GitHub Pages deploys repository pages at `user.github.io/REPONAME`. Hence for Pollen.jl,
    you could pass `hostpath = "Pollen.jl"` to make sure the generated pages will link
    correctly between each other.
- `datadir = nothing`: If a file path, use this to build the Pollen.jl document files to
- `frontenddir = nothing`: If a file path, use this as the frontend repository. If
    `nothing`, clones and installs a fresh version of the Pollen.jl frontend repository.
"""
function prerenderdocs(
    pkgdir;
    tag = "dev",
    env = Dict{String,String}(),
    datadir = nothing,
    frontenddir = nothing,
    hostpath = nothing,
)
    docdir = joinpath(pkgdir, "docs")
    return PkgTemplates.with_project(docdir) do
        # Load project
        @info "Loading project"
        m = Module(Symbol("$(splitpath(pkgdir)[end])Docs"))
        Base.include(m, joinpath(docdir, "project.jl"))
        project = Base.invokelatest(m.createproject, tag = tag)

        # Rewrite documents
        @info "Rewriting documents"
        Pollen.rewritesources!(project)

        # Build documents
        @info "Building files"
        if isnothing(datadir)
            datadir = mktempdir()
        end
        builder = FileBuilder(JSONFormat(), datadir)
        Pollen.fullbuild(project, builder)

        # Set up frontend project
        if isnothing(frontenddir)
            @info "Setting up clean frontend repository"
            frontenddir = mktempdir()
            Pollen.frontend_install(frontenddir, npm = "npm")
        end

        mv(datadir, joinpath(frontenddir, "static", "data"), force = true)

        @info "Build frontend"
        cd(frontenddir) do
            if !isnothing(hostpath)
                env =
                    merge(env, Dict("CI" => "true", "GITHUB_REPOSITORY" => "X/$(hostpath)"))
            end
            run(addenv(`npm run build`, pairs(env)...))
        end
        return joinpath(frontenddir, "build")
    end
end


function deploydocs(pkgdir, remoteurl; staticbranch = "gh-pages", databranch = "pollen", push = true, kwargs...)
    pagesdir = mktempdir()
    @info "Cloning static site branch $staticbranch from remote $remoteurl to temporary directory $pagesdir"
    run(Git.git(["clone", "-b", staticbranch, "--depth", "1", remoteurl, pagesdir]))

    datadir = mktempdir()
    @info "Cloning Pollen.jl data branch $databranch from remote $remoteurl to temporary directory $pagesdir"
    run(Git.git(["clone", "-b", databranch, "--depth", "1", remoteurl, datadir]))

    @info "Building docs"
    builddir = prerenderdocs(pkgdir; hostpath = _getreponame(remoteurl), datadir, kwargs...)

    @info "Moving built files to repository"
    cd(builddir) do
        for p in walkpath(Path("."))
            cp(p, joinpath(Path(pagesdir), p), force = true)
        end
    end

    if push
        @info "Pushing to remote"
        cd(pagesdir) do
            run(Git.git(["add", "."]))
            run(Git.git(["commit", "-m", "Pollen.jl local documentation deploy"]))
            run(Git.git(["push"]))
        end
    end

    return (; builddir, pagesdir)

end


function _getreponame(repositoryurl)
    name = split(repositoryurl, "/")[end]
    name = endswith(name, ".git") ? name[begin:end-4] : name
    return name
end


@testset "validatedocs" begin mktempdir() do dir
    @test_throws ArgumentError validatedocs(dir)
end end
