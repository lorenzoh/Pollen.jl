
# ## Documenter.jl compatibility

function isdocumenterproject(dir::String)
    docprojectfile = joinpath(dir, "docs", "Project.toml")
    isfile(docprojectfile) || return false
    docproject = TOML.parsefile(docprojectfile)
    "Documenter" in keys(docproject["deps"]) || return false
    isfile(joinpath(dir, "docs", "make.jl"))
end


function load_documenter_config(config_package::ConfigProjectPackage)
    file = joinpath(config_package.dir, "docs", "make.jl")
    doc = Pollen.parse(Path(file), JuliaSyntaxFormat())
    toc = _load_documenter_toc(doc, config_package)
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


# Everything below is a hack to extract Documenter.jl-specific information like the
# Table of Contents and Project title from Documenter's `docs/make.jl` file.

function _load_documenter_toc(doc::Node, config_package::ConfigProjectPackage)
    # Load the vector of (name => path) pairs from Documenter.jl's `make.jl` file
    documenter_links = _parse_documenter_toc(doc)

    # Convert it to an ordered dictionary, similar to Pollen.jl's representation
    documenter_toc = _convert_documenter_toc(documenter_links)

    # Then, resolve all links in the ToC, turning them into absolute links.
    # FIXME: link resolution
    toc = resolve_toc(documenter_toc, config_package.name, "docs/src/")
    return toc
end

_convert_documenter_toc(toc::Vector{<:Pair}) = OrderedDict(k => _convert_documenter_toc(v) for (k, v) in toc)
_convert_documenter_toc(entry::String) = entry

function _parse_documenter_toc(doc::Node)
    kw = selectfirst(doc, SelectKwarg("pages"))
    isnothing(kw) && return nothing
    m = Module(Symbol("__documenter_toc"))
    s = gettext(kw)
    Base.include_string(m, s)
end

function resolve_toc(toc, package, dir = "")
    # Fake source file from which the links are resolved
    docid = joinpath("doc", package, dir, "index.md")
    return __mapdictleaves(toc) do link
        parselink(
            InternalLinkRule(),
            LinkInfo(string(link), "", docid, Node(:no), "", package, nothing),
        )
    end
end


function __mapdictleaves(f, d::Union{<:Dict, <:JSON3.Object, <:OrderedDict})
    OrderedDict(map((k, v) -> (k => __mapdictleaves(f, v)), keys(d), values(d)))
end
__mapdictleaves(f, x) = f(x)

function _parse_documenter_sitename(doc::Node)
    kw = selectfirst(doc, SelectKwarg("sitename"))
    isnothing(kw) && return nothing
    return gettext(kw.children[end].children[2])
end

function SelectKwarg(name::String)
    return SelectTag(:kw) & Pollen.SelectCondition() do node
        return node.children[1].children[1][] == name
    end
end

@testset "Project Documenter.jl compat" begin
    @test isdocumenterproject(pkgdir(AbstractTrees))
    @test !isdocumenterproject(pkgdir(Pollen))
end
