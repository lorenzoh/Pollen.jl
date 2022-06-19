

"""
    PackageDocumentation(modules) <: Rewriter

This rewriter sets up tables of a modules' symbols and source files.
Each reference can be its own document, with metadata for that symbol stored in its
attributes and the docstring stored as a child X-tree.

It exports all symbols with metadata relevant to what kind of a symbol it is, e.g.
method data for a function.

The source files are gathered from the module info, and are new document type.
"""
mutable struct PackageDocumentation <: Rewriter
    info::Dict
    dirty::Bool
end


function PackageDocumentation(ms::Union{Module,AbstractVector{Module}})
    info = Dict(k => DataFrame(v) for (k, v) in moduleinfo(ms))
    return PackageDocumentation(info, true)
end

function createsources!(pkgdoc::PackageDocumentation)
    pkgdoc.dirty || return Dict{String,Node}()

    # Documents for source files
    df = innerjoin(
        pkgdoc.info[:sourcefiles],
        pkgdoc.info[:packages],
        on = :package_id,
        validate = false => true,
    )
    docnames = map(r -> joinpath("sourcefiles", r.name, r.file), eachrow(df))
    docpaths = map(r -> joinpath(r.basedir, r.file), eachrow(df))
    sourcedocs = Dict{String,Node}(
        name => createsourcefiledoc(path, name) for (name, path) in zip(docnames, docpaths)
    )

    # Documents for symbols
    symboldocs = Dict{String,Node}()
    df_docstrings = outerjoin(
        pkgdoc.info[:symbols][:, [:symbol_id, :name, :kind, :instance]],
        pkgdoc.info[:docstrings],
        on = :symbol_id,
    )

    for row in eachrow(df_docstrings)
        children = try
            ismissing(row.docstring) ? XTree[] : XTree[parse(row.docstring, MarkdownFormat())]
        catch e
            @error "Could not parse docstring for symbol $(row.symbol_id)" docstring=row.docstring
            rethrow()
        end
        if row.kind == "const"
            push!(children,
                  createcodecell(
                      Node(:codeblock, Leaf(string(row.symbol_id)), lang = "julia"),
                      "",
                      row.instance,
                  )
            )
        end
        doc = Node(
            :documentation,
            children,
            Dict{Symbol,Any}(:symbol_id => row.symbol_id, :title => row.name),
        )
        symboldocs["references/$(row.symbol_id)"] = doc
    end


    docs = merge(sourcedocs, symboldocs)

    pkgdoc.dirty = false

    return docs
end

# TODO: implement source file reloading
#=
function geteventhandler(folder::PackageDocumentation, ch)
    documents = Dict{String, String}(string(_getpath(folder, docid)) => docid for docid in keys(folder.documents))
    return createfilewatcher(documents, ch) do file
        loadfile(folder, file)
    end
end
=#

function createsourcefiledoc(path, name)
    title = joinpath(splitpath(string(name))[2:end]...)
    doc = Pollen.parse(String(read(path)), JuliaSyntaxFormat())
    doc = preparesourcefile(doc)
    return Node(
            :sourcefile,
            [doc],
            Dict{Symbol,Any}(:path => string(path), :title => title,
                             :module => split(name, "/")[2]),
        )
end


function rewritedoc(pkgdoc::PackageDocumentation, path, doc)
    # Parse links into references to documents, symbols or URLs
    doc = addlinkreferences(doc, path, pkgdoc.info[:symbols])
    doc = addidentifierreferences(doc, pkgdoc.info[:symbols])

    # Add symbol metadata as attributes
    attrs = attributes(doc)
    if matches(SelectTag(:documentation), doc)
        doc =
            withattributes(doc, merge(attrs, referencedata(attrs[:symbol_id], pkgdoc.info)))
    end

    return doc
end


function addlinkreferences(doc, path, symbols)
    return cata(doc, SelectTag(:a) & SelectHasAttr(:href)) do x
        linktoreference(x, path, symbols)
    end
end


function addidentifierreferences(doc, symbols)
    cata(doc, SelectTag(:IDENTIFIER)) do x
        s = strip(Pollen.gettext(x), [' ', '\n', ';'])
        symbolid = Pollen.resolvesymbol(symbols, s)
        return if isnothing(symbolid)
            x
        else
            Node(
                :reference,
                children(x),
                merge(
                    attributes(x),
                    Dict(:document_id => "references/$symbolid", :reftype => "symbol"),
                ),
            )
        end
    end
end

SelectReference() = SelectTag(:reference) & SelectHasAttr(:document_id)
SelectSymbolReference() = SelectReference() & SelectAttrEq(:reftype, "symbol")
SelectDocumentReference() = SelectReference() & SelectAttrEq(:reftype, "document")

#= ## Link classification

A link can be to a document, a symbol/module, a source file, or an external URL.
They can be differentiated as follows:

- `[`Module.symbol`](#)`: a symbol/module reference marked by a link target `#`.
    If the symbol is not given with a fully qualified module path, this is
    resolved by looking at a list of modules and determining the parent module.
- `[link text](/path/to/document)` an absolute or relative file path pointing to
    a document.
- `[link text](https://fluxml.ai)` a URL to an external resource.

Based on this scheme, the links are classified and then given a semantic tag, one of
`:refsymbol`, `:refdocument`, `:refurl`. These are represented as a X-node with the
link text stored as a child string, and the kind of link as well as the target
stored as the attribute.

```julia
Node(:refsymbol, Dict(:symbol_id => "DataLoaders.DataLoader"), [Leaf("DataLoader")])
```

=#

function linktoreference(x, docid, symbols)
    text = gettext(x)
    if issymbolref(x)
        symbol_id = resolvesymbol(symbols, text)
        if isnothing(symbol_id)
            @info "Could not resolve identifier `$text`."
            return only(children(x))
        else
            return Node(
                :reference,
                children(x),
                Dict(:document_id => "references/$symbol_id", :reftype => "symbol"),
            )
        end
    elseif isurlref(x)
        x
    else
        href = attributes(x)[:href]
        if !startswith(href, "/")
            href = normpath(joinpath(parent(Path(docid)), href))
        else
            href = href[2:end]
        end
        return Node(
            :reference,
            children(x),
            merge(
                attributes(x),
                Dict(:document_id => string(href), :reftype => "document"),
            ),
        )
    end

end


issymbolref(x::Node) = (
    length(children(x)) == 1 &&
    only(children(x)) isa Node &&
    (tag(only(children(x))) == :code) &&
    get(attributes(x), :href, "") == "#"
)

isurlref(x::Node) = startswith(get(attributes(x), :href, ""), r"http(s)?://")

function resolvesymbol(df, identifier::AbstractString; all = true)
    if identifier ∈ df.symbol_id
        return identifier
    else
        if all
            i = findfirst(r -> isshortidentifier(r.symbol_id, identifier), eachrow(df))
        else
            i = findfirst(r -> r.public && r.name == identifier, eachrow(df))
        end
        if isnothing(i)
            return nothing
        else
            return df.symbol_id[i]
        end
    end
end


function isshortidentifier(full, short)
    fullparts = split(full, ".")
    shortparts = split(short, ".")
    length(shortparts) > length(fullparts) && return false
    for i in 1:length(shortparts)
        shortparts[end-(i-1)] == fullparts[end-(i-1)] || return false
    end
    return true
end


##

function referencedata(symbol_id, info)
    i = findfirst(==(symbol_id), info[:symbols].symbol_id)
    isnothing(i) && return Dict{Symbol,Any}()
    symbol = info[:symbols][i, :]

    return merge(
        Dict([(k, v) for (k, v) in pairs(symbol) if k != :instance]),
        referencedata(symbol, info, Val{}(Symbol(symbol.kind))),
    )
end


function referencedata(symbol, info, ::Val{:function})
    return Dict(:methods => _getmethods(info, symbol.symbol_id))
end

function referencedata(symbol, info, ::Val{:struct})
    return Dict(:methods => _getmethods(info, symbol.symbol_id))
end

function referencedata(symbol, info, ::Val{Symbol("abstract type")})
    return Dict(:methods => _getmethods(info, symbol.symbol_id))
end

# TODO: gather information from submodules
function referencedata(symbol, info, ::Val{:module})
    moduleid = ModuleInfo.getmoduleid(symbol.instance)
    row_module = info[:modules][findfirst(==(moduleid), info[:modules].module_id), :]
    msymbols = info[:symbols][info[:symbols].module_id.==moduleid, :]
    symbols = [
        Dict(
            :symbol_id => row.symbol_id,
            :name => row.name,
            :public => row.public,
            :kind => row.kind,
        ) for row in eachrow(msymbols) if row.symbol_id != moduleid
    ]
    joinedfiles = innerjoin(info[:sourcefiles],
                            info[:packages][info[:packages].package_id .== row_module.package_id, :];
                            on = :package_id)
    files = [joinpath(row.basedir, row.file)
                for row in eachrow(joinedfiles)
                    if row.package_id == row_module.package_id]
    # document IDs of source files
    filedocs = [
        joinpath(["sourcefiles", row.name, row.file])
            for row in eachrow(joinedfiles)]
    return Dict(:symbols => symbols, :files => files, :filedocs => filedocs)
end



function _getmethods(info, symbol_id)
    methods = info[:methods][info[:methods].symbol_id.==symbol_id, :]

    return [
        Dict(
            :line => row.line,
            :file => row.file,
            :filedoc => __getfiledoc(row),
            :method_id => row.method_id,
            :symbol_id => row.symbol_id,
            :signature => row.signature,
        ) for row in eachrow(methods)
    ]
end

function __getfiledoc(row)
    pkg = split(row.symbol_id, '.')[1]
    parts = split(row.file, "/")
    i = findfirst(==("src"), parts)
    if !isnothing(i)
        joinpath("sourcefiles", pkg, parts[i:end]...)
    else
        i = findfirst(==("julia"), parts)
        if !isnothing(i)
            return joinpath("sourcefiles", pkg, parts[i:end]...)
        else
            return joinpath("sourcefiles/unknown/$(parts[end])")
        end
    end
end

function referencedata(symbol, info, ::Val)
    return Dict{Symbol,Any}()
end

@testset "PackageDocumentation [rewriter]" begin
    rewriter = PackageDocumentation([Pollen])
end





function preparesourcefile(tree)
    tree = tree |> stripdocstrings |> splitoncomments
end

function stripdocstrings(tree)
    Pollen.cata(tree, SelectTag(:MACROCALL)) do node
        isempty(children(node)) && return node
        if tag(first(children(node))) == :CORE_DOC_MACRO_NAME
            return children(node)[end]
        else
            return node
        end
    end
end


function splitoncomments(node)
    chs = Node[]

    in_comment = false

    comment = String[]
    code = Node[]

    for ch in children(node)

        if tag(ch) === :COMMENT
            if !isempty(code)
                push!(chs, Node(:codeblock, code...; lang = "julia"))
                code = Node[]
            end
            in_comment = true
            push!(comment, _strip_comment(Pollen.gettext(ch)))
            push!(comment, " ")
        elseif in_comment & (tag(ch) == :NEWLINE_WS || tag(ch) == :WHITESPACE)
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
        return strip(str[3:end-2])
    else
        return strip(str[2:end])
    end
end
