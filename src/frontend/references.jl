

"""
    PackageDocumentation(modules)

This rewriter sets up a complete table of a module's symbols and its source files.
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
    pkgdoc.dirty || return Dict{AbstractPath,XTree}()

    # Documents for source files
    df = innerjoin(
        pkgdoc.info[:sourcefiles],
        pkgdoc.info[:packages],
        on = :package_id,
        validate = false => true,
    )
    docnames = map(r -> Path(joinpath("sourcefiles", r.name, r.file)), eachrow(df))
    docpaths = map(r -> Path(joinpath(r.basedir, r.file)), eachrow(df))
    sourcedocs = Dict{AbstractPath,XTree}(
        name => createsourcefiledoc(path, name) for (name, path) in zip(docnames, docpaths)
    )

    # Documents for symbols
    symboldocs = Dict{AbstractPath,XTree}()
    df_docstrings = outerjoin(
        pkgdoc.info[:symbols][:, [:symbol_id, :name]],
        pkgdoc.info[:docstrings],
        on = :symbol_id,
    )

    for row in eachrow(df_docstrings)
        children = ismissing(row.docstring) ? XNode[] : [parse(row.docstring, Markdown())]
        doc = XNode(
            :documentation,
            Dict{Symbol,Any}(:symbol_id => row.symbol_id, :title => row.name),
            children,
        )
        symboldocs[Path(joinpath("references", row.symbol_id))] = doc
    end


    docs = merge(sourcedocs, symboldocs)

    pkgdoc.dirty = false

    return docs
end

function createsourcefiledoc(path, name)
    title = joinpath(splitpath(string(name))[2:end]...)
    return withattributes(
        Pollen.parse(String(read(path)), JuliaCodeFormat()),
        Dict{Symbol,Any}(:path => string(path), :title => title),
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
    cata(doc, SelectTag(:CST_IDENTIFIER)) do x
        s = strip(Pollen.gettext(x), [' ', '\n', ';'])
        symbolid = Pollen.resolvesymbol(symbols, s)
        return if isnothing(symbolid)
            x
        else
            XNode(
                :reference,
                merge(attributes(x), Dict(:document_id => "references/$symbolid", :reftype => "symbol")),
                children(x),
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
XNode(:refsymbol, Dict(:symbol_id => "DataLoaders.DataLoader"), [XLeaf("DataLoader")])
```

=#

function linktoreference(x, path, symbols)
    text = gettext(x)
    if issymbolref(x)
        symbol_id = resolvesymbol(symbols, text)
        if isnothing(symbol_id)
            @info "Could not resolve identifier `$text`."
            return only(children(x))
        else
            return XNode(
                :reference,
                Dict(:document_id => "references/$symbol_id", :reftype => "symbol"),
                children(x),
            )
        end
    elseif isurlref(x)
        x
    else
        href = attributes(x)[:href]
        if !startswith(href, "/")
            href = normpath(joinpath(parent(path), href))
        end
        return XNode(
            :reference,
            merge(attributes(x), Dict(:document_id => string(href), :reftype => "document")),
            children(x),
        )
    end

end


issymbolref(x::XNode) = (
    length(children(x)) == 1 &&
    only(children(x)) isa XNode &&
    (tag(only(children(x))) == :code) &&
    get(attributes(x), :href, "") == "#"
)

isurlref(x::XNode) = startswith(get(attributes(x), :href, ""), r"http(s)?://")

function resolvesymbol(df, identifier::AbstractString; all = true)
    if identifier ∈ df.symbol_id
        return identifier
    else
        if all
            i = findfirst(r -> r.name == identifier, eachrow(df))
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

function _getmethods(info, symbol_id)
    methods = info[:methods][info[:methods].symbol_id.==symbol_id, :]
    return [
        Dict(
            :line => row.line,
            :file => row.file,
            :method_id => row.method_id,
            :symbol_id => row.symbol_id,
            :signature => row.signature,
        ) for row in eachrow(methods)
    ]
    return map(row -> Dict(zip(keys(row), values(row))), eachrow(methods))
end

function referencedata(symbol, info, ::Val)
    return Dict{Symbol,Any}()
end
