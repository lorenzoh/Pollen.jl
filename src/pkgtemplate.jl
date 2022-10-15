
const POLLEN_TEMPLATE_DIR = Ref{String}(joinpath(dirname(dirname(pathof(Pollen))),
                                                 "templates"))

"""
    PollenPlugin(; kwargs...) <: Plugin

Configuration for setting up Pollen.jl documentation for a package.

To add documentation when creating a package with PkgTemplates.jl, use this as one
of the plugins.

To add documentation to an existing package, you can configure this and pass it to
[`setup_docs_files`](#), [`setup_docs_project`](#), [`setup_docs_actions`](#) and
[`setup_docs_branches`](#). See these functions for more detail on what is set up.

Follow [the tutorial](/doc/docs/tutorials/setup.md) for a step-by-step guide for
setting up documentation.

## Keyword arguments

- `folder::String = "docs"`: The folder in which the documentation configuration
    and project will be stored. See [`setup_docs_files`](#) and [`setup_docs_project`](#).
- `remote = "origin"`: The name of the remote to use. Branches created by
    [`setup_docs_branches`](#) will be pushed to this remote. Set `remote = nothing` to
    disable the pushing of branches to a remote.

    !!! warn "Missing remote"

        If the remote does not exist, the setup will error! In that case, disable with
        `remote = nothing`.

Branch configuration:

- `branch_primary = "main"`: The main branch of the repository. Pushes to this branch
    will trigger documentation builds on GitHub.

    !!! warn "Old repositories"

        If your repository was created a while ago, chances are its default branch is called
        `"master"`. In that case, you will have to pass `branch_primary = "master"` or
        the GitHub Actions will not be set up correctly.
- `branch_data = "pollen"`: Pollen.jl will create a branch in your repository that stores
    data generated during documentation build on GitHub Pages. You will usually not need to
    change this.
- `branch_page = "gh-pages"`: The branch that the statically rendered HTML is built to for
    publishing on GitHub Pages.

Dependency configuration:

- `pollen_spec::Pkg.PackageSpec`: If you want to use an in-development version/branch of
    Pollen.jl, modify this to ensure that GitHub Actions will also that version.
"""
@plugin struct PollenPlugin <: Plugin
    folder::String = "docs"
    branch_data::String = "pollen"
    branch_page::String = "gh-pages"
    branch_primary::String = "main"
    remote::Union{String, Nothing} = "origin"
    pollen_spec::Pkg.PackageSpec = Pkg.PackageSpec(url = "https://github.com/lorenzoh/Pollen.jl",
                                                   rev = "main")
    moduleinfo_spec::Pkg.PackageSpec = Pkg.PackageSpec(url = "https://github.com/lorenzoh/ModuleInfo.jl",
                                                       rev = "main")
end

# Setup and validation steps

function setup_docs(dir::String,
                    plugin = Pollen.PollenPlugin();
                    verbose = true,
                    force = false)
    # ## Checks
    # check isdir
    isdir(dir) || throw(SystemError("Directory `$dir` not found!"))
    # check isfile Project.toml
    projfile = joinpath(dir, "Project.toml")
    if !isfile(projfile)
        throw(SystemError("Project file `$dir/Project.toml` not found! Please pass a valid Julia package directory."))
    end

    verbose && @info "Rendering templates in docs subfolder `$(plugin.folder)"
    setup_docs_files(dir, plugin; verbose, force)
    verbose && @info "Rendering GitHub Actions templates in `.github/worflows`"
    setup_docs_actions(dir, plugin; verbose, force)
    verbose &&
        @info "Setting up Julia project with docs dependencies in subfolder `$(plugin.folder)`"
    setup_docs_project(dir, plugin; verbose, force)

    if verbose
        @info "If you want to host a site on GitHub Pages and haven't done so, check and
        commit the changes made by `setup_docs` and then run `setup_docs_branches`."
    end
end

TEMPLATES_DOCS = ["project.jl", "make.jl", "serve.jl", "toc.json"]
TEMPLATES_ACTIONS = [
    "pollen.build.yml",
    "pollen.trigger.dev.yml",
    "pollen.trigger.pr.yml",
    "pollen.trigger.release.yml",
    "pollen.render.yml",
]

function setup_docs_files(dir::String,
                          plugin = PollenPlugin();
                          verbose = true,
                          force = false)
    # Validation
    isdir(dir) || throw(SystemError("Directory `$dir` not found!"))
    docsdir = joinpath(dir, plugin.folder)
    isdir(docsdir) || mkdir(docsdir)
    docsfiles = [joinpath(docsdir, f) for f in TEMPLATES_DOCS]
    for file in docsfiles
        if !force && isfile(file)
            throw(SystemError("File `$file` already exists. Pass `force = true` to overwrite any previous configuration.",
                              2))
        end
    end

    # Running

    config = _docs_config(dir, plugin)
    for template in TEMPLATES_DOCS
        _rendertemplate(template, docsdir, config)
    end
end

function setup_docs_actions(dir::String,
                            plugin = PollenPlugin();
                            verbose = true,
                            force = false)
    # Validation
    isdir(dir) || throw(SystemError("Directory `$dir` not found!"))
    actionsdir = joinpath(dir, ".github/workflows")
    isdir(actionsdir) || mkpath(docsdir)
    actionfiles = [joinpath(actionsdir, f) for f in TEMPLATES_ACTIONS]
    for file in actionfiles
        if !force && isfile(file)
            throw(SystemError("File `$file` already exists. Pass `force = true` to overwrite any previous configuration.",
                              2))
        end
    end

    # Write the files
    config = _docs_config(dir, plugin)
    for template in TEMPLATES_ACTIONS
        _rendertemplate(template, actionsdir, config)
    end
end

function setup_docs_branches(dir::String, plugin = PollenPlugin(); force = false)
    if !_iscleanworkingdir(dir)
        throw(SystemError("""The working directory of git repository $dir is not clean. Please
                             commit or stash all changes before running `setup_docs_branches`.
                             This will create two branches and push them to the remote, but can
                             only do so with a clean working directory."""))
    end
    # Create orphaned branch `pollen` that stores the documentation data (default "pollen")
    # TODO: Maybe add render workflow to this branch
    if !_hasbranch(dir, plugin.branch_data) || force
        _createorphanbranch(dir, plugin.branch_data, remote = plugin.remote)
    end

    # Create orhpaned branch that the website will be built to (default "gh-pages")
    if !_hasbranch(dir, plugin.branch_page) || force
        _createorphanbranch(dir, plugin.branch_page, remote = plugin.remote)
        # TODO: add .nojekyll file
        _withbranch(dir, plugin.branch_page) do
            touch(".nojekyll")
            Git.git(["add", "."]) |> readchomp |> println
            Git.git(["commit", "-m", "'Add .nojekyll'"]) |> readchomp |> println
        end
    end
end

function setup_docs_project(dir, plugin = PollenPlugin(); force = false, verbose = false)
    isdir(dir) || throw(SystemError("Directory `$dir` not found!"))
    docsdir = joinpath(dir, plugin.folder)
    if isdir(docsdir) && isfile(joinpath(docsdir, "Project.toml"))
        force ||
            throw(SystemError("There is already a Julia project at `$docsdir`. Pass `force = true` to overwrite."))
    end
    isdir(docsdir) || mkdir(docsdir)
    # TODO: check if it
    cd(dir) do
        PkgTemplates.with_project(docsdir) do
            Pkg.add([plugin.pollen_spec, plugin.moduleinfo_spec])
            Pkg.develop(Pkg.PackageSpec(path = dir))
        end
    end
end

function _rendertemplate(name, dst, config)
    PkgTemplates.gen_file(joinpath(dst, name),
                          PkgTemplates.render_file(joinpath(POLLEN_TEMPLATE_DIR[], name),
                                                   config,
                                                   ("<<", ">>")))
end

function _docs_config(dir::String, plugin::PollenPlugin)
    return Dict{String, Any}("PKG" => split(dir, "/")[end],
                             "DOCS_FOLDER" => plugin.folder,
                             "BRANCH_DATA" => plugin.branch_data,
                             "BRANCH_PAGE" => plugin.branch_page,
                             "BRANCH_PRIMARY" => plugin.branch_primary)
end

# Hooks for PkgTemplates

PkgTemplates.priority(::PollenPlugin) = -1000

function PkgTemplates.validate(::PollenPlugin, t::Template) end

function PkgTemplates.prehook(p::PollenPlugin, ::Template, pkg_dir::AbstractString)
    setup_docs_branches(pkg_dir, p)
end

function PkgTemplates.hook(plugin::PollenPlugin, t::Template, pkg_dir::AbstractString)
end

function PkgTemplates.posthook(plugin::PollenPlugin, t::Template, pkg_dir::AbstractString)
    # Setup the environment for building the docs
    setup_docs_project(pkg_dir, plugin)
    setup_docs_files(pkg_dir, plugin)
    setup_docs_actions(pkg_dir, plugin)
    _withbranch(pkg_dir, plugin.branch_primary) do
        Git.git(["add", "."]) |> readchomp |> println
        Git.git(["commit", "-m", "'Setup Pollen.jl template files'"]) |>
        readchomp |>
        println
    end
    setup_docs_branches(pkg_dir, plugin)
end

function PkgTemplates.view(p::PollenPlugin, ::Template, pkg_dir::AbstractString)
    return Dict{String, Any}("PKG" => split(pkg_dir, "/")[end],
                             "DOCS_FOLDER" => p.folder,
                             "BRANCH_PRIMARY" => p.branch_primary,
                             "BRANCH_DATA" => p.branch_data,
                             "BRANCH_PAGE" => p.branch_page)
end

# Git utilities

function _withbranch(f, dir, branch; options = String[], verbose = true)
    _println(args...) = verbose ? println(args...) : nothing

    isdir(dir) || throw(ArgumentError("\"$dir\" is not an existing directory!"))
    isdir(joinpath(dir, ".git")) ||
        throw(ArgumentError("\"$dir\" is not a git repository!"))

    cd(dir) do
        prevbranch = readchomp(Git.git(["branch", "--show-current"]))
        try
            Git.git(["checkout", options..., branch]) |> readchomp |> _println
            f()
        catch e
            rethrow()
        finally
            Git.git(["checkout", prevbranch]) |> readchomp |> _println
        end
    end
end

function _hasbranch(dir, branch)
    try
        cd(() -> pipeline(Git.git(["rev-parse", "--quiet", "--verify", branch])) |>
                 readchomp,
           dir)
        return true
    catch
        return false
    end
end

function _iscleanworkingdir(dir)
    cd(dir) do
        isempty(strip(readchomp(Pollen.Git.git(["status", "-s"]))))
    end
end

function _createorphanbranch(repo::String, branch::String; remote = nothing)
    return _withbranch(repo, branch, options = ["--orphan"]) do
        @info "Creating orphaned branch `$branch`"
        readchomp(Git.git(["reset", "--hard"]))
        readchomp(Git.git([
                              "commit",
                              "--allow-empty",
                              "-m",
                              "Empty branch for Pollen.jl data",
                          ]))
        if !isnothing(remote)
            try
                readchomp(Git.git(["push", "--set-upstream", remote, branch]))
            catch
                @error """Could not push branch `$branch` to remote. You may have to do
                        this manually later."""
            end
        end
    end
end

# Tests

@testset "Documentation setup" begin @testset "PkgTemplates" begin
    template = Template(plugins = [
                            Pollen.PollenPlugin(remote = nothing),
                            PkgTemplates.Git(ssh = true),
                        ], user = "lorenzoh")

    @test_nowarn redirect_stderr(Base.DevNull()) do
        redirect_stdout(Base.DevNull()) do
            template(joinpath(mktempdir(), "TestPackage"))
        end
    end
end end
