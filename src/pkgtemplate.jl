

const POLLEN_TEMPLATE_DIR = Ref{String}(joinpath(dirname(dirname(pathof(Pollen))), "templates"))

const git = Git.git()

"""
    PollenPlugin() <: Plugin

Sets up Pollen.jl documentation for a package.

## Extended

Performs the following steps:

- creates a `docs/` folder with default files `project.jl`, `serve.jl`, `make.jl`
    and `toc.json`
- creates the GitHub actions for building the documentation data and the frontend
- creates an empty (orphan) branch "pollen" where documentation data will be built to
    by GitHub Actions
"""
@plugin struct PollenPlugin <: Plugin
    folder::String = "docs"
    branch_data::String = "pollen"
    branch_page::String = "gh-pages"
    branch_primary::String = "main"
end

PkgTemplates.priority(::PollenPlugin) = -1000

function PkgTemplates.validate(::PollenPlugin, t::Template)
end


function PkgTemplates.prehook(p::PollenPlugin, ::Template, pkg_dir::AbstractString)
    # branch where Pollen output data will be stored (default "pollen")
    _hasbranch(pkg_dir, p.branch_data) || _createorphanbranch(pkg_dir, p.branch_data)
    # branch that the website will be built to (default "gh-pages")
    _hasbranch(pkg_dir, p.branch_page) || _createorphanbranch(pkg_dir, p.branch_page)
end


function _createorphanbranch(repo::String, branch::String)
    return _withbranch(repo, branch, options=["--orphan"]) do
        readchomp(Git.git(["reset", "--hard"])) |> println
        readchomp(Git.git(["commit", "--allow-empty", "-m", "Empty branch for Pollen.jl data"])) |> println
    end
end


function PkgTemplates.hook(p::PollenPlugin, t::Template, pkg_dir::AbstractString)


    println("hook", cd(() -> readchomp(Git.git(["branch", "--show-current"])), pkg_dir))

    # create template files
    folder_docs = mkpath(joinpath(pkg_dir, p.folder))

    config = PkgTemplates.view(p, t, pkg_dir)
    rendertemplate(templatename, dst) = gen_file(
        joinpath(dst, templatename),
        render_file(
            joinpath(POLLEN_TEMPLATE_DIR[], templatename),
            config,
            ("<<", ">>"))
    )

    rendertemplate("project.jl", folder_docs)
    rendertemplate("make.jl", folder_docs)
    rendertemplate("serve.jl", folder_docs)
    rendertemplate("toc.json", folder_docs)

    folder_actions = mkpath(joinpath(pkg_dir, ".github/workflows"))
    rendertemplate("pollenbuild.yml", folder_actions)
    rendertemplate("pollenstatic.yml", folder_actions)

    _withbranch(pkg_dir, p.branch_primary) do
        Git.git(["add", "."]) |> readchomp |> println
        Git.git(["commit", "-m", "'Setup Pollen.jl template files'"]) |> readchomp |> println
    end
end


function PkgTemplates.posthook(p::PollenPlugin, t::Template, pkg_dir::AbstractString)
    # Setup the environment for building the docs
    folder_docs = mkpath(joinpath(pkg_dir, p.folder))
    setuppollenenv(folder_docs, pkg_dir)

    # Workflow needs to be on this branch as well
    config = PkgTemplates.view(p, t, pkg_dir)
    rendertemplate(templatename, dst) = gen_file(
        joinpath(dst, templatename),
        render_file(
            joinpath(POLLEN_TEMPLATE_DIR[], templatename),
            config,
            ("<<", ">>"))
    )
    folder_actions = mkpath(joinpath(pkg_dir, ".github/workflows"))


    _withbranch(pkg_dir, p.branch_data) do
        rendertemplate("pollenbuild.yml", folder_actions)
        rendertemplate("pollenstatic.yml", folder_actions)
        Git.git(["add", "."]) |> readchomp |> println
        Git.git(["commit", "-m", "Add actions to data branch"]) |> readchomp |> println
    end
    _withbranch(pkg_dir, p.branch_page) do
        touch(".nojekyll")
        Git.git(["add", "."]) |> readchomp |> println
        Git.git(["commit", "-m", "Add .nojekyll"]) |> readchomp |> println
    end
    sleep(0.1)
end


function PkgTemplates.view(p::PollenPlugin, ::Template, pkg_dir::AbstractString)
    return Dict{String, Any}(
        "PKG" => split(pkg_dir, "/")[end],
        "DOCS_FOLDER" => p.folder,
        "BRANCH_DATA" => p.branch_data,
        "BRANCH_PAGE" => p.branch_page,
    )
end

function setuppollenenv(dir::String, pkgdir::String)
    cd(pkgdir) do
        PkgTemplates.with_project(dir) do
            Pkg.add([
                Pkg.PackageSpec(url="https://github.com/c42f/JuliaSyntax.jl"),
                Pkg.PackageSpec(url="https://github.com/lorenzoh/ModuleInfo.jl"),
                Pkg.PackageSpec(url="https://github.com/lorenzoh/Pollen.jl", rev="main"),
            ])
            Pkg.develop(Pkg.PackageSpec(path=pkgdir))
        end
        Git.git(["add", "."]) |> readchomp |> println
        Git.git(["commit", "-m", "'Pollen.jl: setup docs/ project'"]) |> readchomp |> println
    end
end


function _withbranch(f, dir, branch; options = String[], verbose = true)
    _println(args...) = verbose ? println(args...) : nothing

    isdir(dir) || throw(ArgumentError("\"$dir\" is not an existing directory!"))
    isdir(joinpath(dir, ".git")) || throw(ArgumentError("\"$dir\" is not a git repository!"))

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


_hasbranch(dir, branch) = try
    cd(() -> pipeline(Git.git(["rev-parse", "--quiet", "--verify", branch])) |> readchomp, dir)
    return true
catch
    return false
end
