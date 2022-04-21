

const POLLEN_TEMPLATE_DIR = Ref{String}(joinpath(dirname(dirname(pathof(Pollen))), "templates"))

const git = Git.git()

"""
    PollenPlugin() <: Plugin

Sets up Pollen.jl documentation for a package.

## Extended

Performs the following steps:

- creates a `docs/` folder with default files `project.jl`, `serve.jl`, `make.jl`
    and `toc.json`
"""
@plugin struct PollenPlugin <: Plugin
    folder::String = "docs"
    branch_data::String = "pollen"
    branch_page::String = "gh-pages"
end


function PkgTemplates.validate(::PollenPlugin, t::Template)
end

function PkgTemplates.prehook(p::PollenPlugin, t::Template, pkg_dir::AbstractString)
    createorphanbranch(pkg_dir, p.branch_data)
end

function createorphanbranch(repo::String, branch::String)
    cd(repo) do
        prevbranch = readchomp(Git.git(["branch", "--show-current"]))
        try
            readchomp(Git.git(["checkout", "--orphan", branch])) |> println
            readchomp(Git.git(["reset", "--hard"])) |> println
            touch(".nojekyll")
            readchomp(Git.git(["commit", "--allow-empty", "-m", "Empty branch for Pollen.jl data"])) |> println
        catch e
            @error "Failed to create orphan branch $branch" e=e
        finally
            Git.git(["checkout", prevbranch])
        end
    end
end

function PkgTemplates.hook(p::PollenPlugin, t::Template, pkg_dir::AbstractString)

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

end


function PkgTemplates.posthook(p::PollenPlugin, t::Template, pkg_dir::AbstractString)
    # Setup the environment for building the docs
    folder_docs = mkpath(joinpath(pkg_dir, p.folder))
    setuppollenenv(folder_docs, relpath(pkg_dir, folder_docs))
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
    cd(dir) do
        PkgTemplates.with_project(dir) do
            Pkg.status()
            Pkg.add([
                Pkg.PackageSpec(url="https://github.com/c42f/JuliaSyntax.jl"),
                Pkg.PackageSpec(url="https://github.com/lorenzoh/ModuleInfo.jl"),
                Pkg.PackageSpec(url="https://github.com/lorenzoh/Pollen.jl", rev="main"),
            ])
            Pkg.develop(Pkg.PackageSpec(path=pkgdir))
        end
    end
end
