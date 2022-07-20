# To allow working with packages that use different flavors of documentation (e.g.
# Pollen.jl or Documenter.jl), this file defines helpers for detecting which style
# a package uses and finding the relevant documentation files.

"""
    abstract type DocumentationStyle

Supertype for different flavors of documentation. See [`DocumenterStyle`](#)
and [`PollenStyle`](#).

"""
abstract type DocumentationStyle end

struct PollenStyle <: DocumentationStyle end
struct DocumenterStyle <: DocumentationStyle end

function finddocumentationfiles(dir::String, ::PollenStyle, extensions)
    # TODO: Detect whether Pollen or Documenter-style is used
    # for now, assume Pollen.jl
    files = reduce(vcat, rglob("*.$ext", dir) for ext in extensions)
end

function findpageindex(dir::String, ::PollenStyle)
    indexfile = joinpath(dir, "docs", "toc.json")
    if isfile(indexfile)
        index = open(f -> JSON3.read(f), indexfile, "r")
    else
        @warn "Page index file 'toc.json' not found in directory '$dir/docs'"
    end
end

function detectdocstyle(dir::String)
    docproj = TOML.readfile(joinpath(dir, "docs", "Project.toml"))
    docdeps = get(docproj, "deps", String[])
    if "Pollen" in docdeps
        return PollenStyle()
    elseif "Documenter" in docdeps
        return DocumenterStyle()
    else
        error("Could not determine documentation flavor for package directory '$dir'")
    end
end

function findpageindex(dir::String, ::DocumenterStyle)
    error("Not implemented!!")
end

function rglob(filepattern = "*", dir = pwd(), depth = 5)
    patterns = ["$(repeat("*/", i))$filepattern" for i in 0:depth]
    return vcat([glob(pattern, dir) for pattern in patterns[1:depth]]...)
end
