
function SourceFiles(pkgdirs::Vector{String}, names::Vector{String})
    # TODO: check for non-existent src dirs
    return DocumentFolder(
        ["src/$name/" => joinpath(pkgdir, "src") for (pkgdir, name) in zip(pkgdirs, names)];
        extensions = ["jl"],
        loadfn = __load_source_file)
end

# TODO: check for non-existent pkgdirs
SourceFiles(ms::Vector{Module}) = SourceFiles(pkgdir.(ms), string.(ms))

# ## Configuration parsing

@option struct ConfigSourceFiles <: AbstractConfig
    # TODO: only index packages, not other info
    index::ConfigPackageIndex = ConfigPackageIndex()
end

configtype(::typeof(SourceFiles)) = ConfigSourceFiles

function from_config(config::ConfigSourceFiles)
    index = from_config(config.index)
    SourceFiles(index.packages.basedir, index.packages.name)
end

# ## Helpers

function __load_source_file(file::String, id)
    doc = Pollen.parse(Path(file), JuliaSyntaxFormat())
    doc = preparesourcefile(doc)

    parts = split(id, "/")
    module_id = parts[begin+1]
    title = "$module_id/$(join(parts[begin+2:end], "/"))"

    return Node(:sourcefile,
                [doc],
                Dict{Symbol, Any}(:path => file, :title => title, :module_id => module_id))
end

# Some helpers for loading source files, ensuring
# 1. inline comments are pased as Markdown
# 2. docstrings are stripped

preparesourcefile(tree) = tree |> __stripdocstrings |> __splitoncomments

function __stripdocstrings(tree)
    Pollen.cata(tree, SelectTag(:MACROCALL)) do node
        isempty(children(node)) && return node
        if tag(first(children(node))) == :CORE_DOC_MACRO_NAME
            return children(node)[end]
        else
            return node
        end
    end
end

# TODO: fix parsing for consecutive comments separated by non-comment whitespace
# TODO: fix parsing inside module definitions
function __splitoncomments(node)
    chs = Node[]

    in_comment = false

    comment = String[]
    code = Node[]

    for ch in children(node)
        if tag(ch) === :Comment
            if !isempty(code)
                push!(chs, Node(:codeblock, code...; lang = "julia"))
                code = Node[]
            end
            in_comment = true
            push!(comment, _strip_comment(Pollen.gettext(ch)))
            push!(comment, " ")
        elseif in_comment && (tag(ch) == :NewlineWs || tag(ch) == :Whitespace)
            continue
        else
            if !isempty(comment)
                push!(chs, Pollen.parse(join(comment), MarkdownFormat()))
                comment = String[]
            end
            in_comment = false
            push!(code, ch)
        end
    end
    isempty(code) || push!(chs, Node(:codeblock, code...; lang = "julia"))
    isempty(comment) || push!(chs, Pollen.parse(join(comment), MarkdownFormat()))

    return Pollen.withchildren(node, chs)
end

function _strip_comment(str)
    if startswith(str, "#=")
        return strip(str[3:(end - 2)])
    else
        return strip(str[2:end])
    end
end
