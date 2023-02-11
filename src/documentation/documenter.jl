
# ## Documenter.jl compatibility

function isdocumenterproject(pkgdir::String)
    docprojectfile = joinpath(pkgdir, "docs", "Project.toml")
    isfile(docprojectfile) || return false
    docproject = TOML.parsefile(docprojectfile)
    "Documenter" in keys(docproject["deps"]) || return false
    isfile(joinpath(pkgdir, "docs", "make.jl"))
end


function load_documenter_config(pkgdir, packageconfig)
    file = joinpath(pkgdir, "docs", "make.jl")
    doc = Pollen.parse(Path(file), JuliaSyntaxFormat())
    toc = _load_documenter_toc(doc, packageconfig)
    title = _parse_documenter_sitename(doc)

    conf = Dict{String, Any}(
        "project" => "./docs",
        "rewriters" => Dict("documenter" => true)
    )
    if toc !== nothing
        conf["contents"] = toc
    end
    if title !== nothing
        conf["title"] = title
    end
    return conf
end

function _load_documenter_toc(doc::Node, projectconfig)
    # Load the vector of (name => path) pairs from Documenter.jl's `make.jl` file
    documenter_links = _parse_documenter_toc(doc, projectconfig)

    # Convert it to an ordered dictionary, similar to Pollen.jl's representation
    documenter_toc = _convert_documenter_toc(documenter_links)

    # Then, resolve all links in the ToC, turning them into absolute links.
    pkgid = projectconfig["name"] * "@" * projectconfig["version"]
    toc = resolve_toc(documenter_toc, pkgid, "docs/src/")
    return toc
end

_convert_documenter_toc(toc::Vector{<:Pair}) = OrderedDict(k => _convert_documenter_toc(v) for (k, v) in toc)
_convert_documenter_toc(entry::String) = entry

function _parse_documenter_toc(doc::Node, pkgid)
    kw = selectfirst(doc, SelectKwarg("pages"))
    isnothing(kw) && return nothing
    m = Module(Symbol("__documenter_toc"))
    s = gettext(kw)
    Base.include_string(m, s)
end

function resolve_toc(toc, pkgid, dir = "")
    # Fake source file from which the links are resolved
    srcfile = joinpath(pkgid, "doc", dir, "index.md")
    return __mapdictleaves(toc) do link
        parselink(
            InternalLinkRule(),
            LinkInfo(string(link), "", srcfile, Node(:no), "", pkgid, nothing),
        )
    end
end


function _parse_documenter_sitename(doc::Node)
    kw = selectfirst(doc, SelectKwarg("sitename"))
    isnothing(kw) && return nothing
    return gettext(kw.children[end].children[2])
end

function SelectFunctionCall(name::String)
    return SelectTag(:call) & Pollen.SelectCondition() do node
        length(children(node)) >= 1 || return false
        id = children(node)[1]
        tag(id) == :Identifier || return false
        idname = gettext(id)
        endswith(idname, name)
    end
end

function SelectKwarg(name::String)
    return SelectTag(:kw) & Pollen.SelectCondition() do node
        return node.children[1].children[1][] == name
    end
end
