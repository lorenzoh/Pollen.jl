
"""
    ModuleReference(modules)
    ModuleReference(pkgindex)

A [`Rewriter`](#) that creates a reference document for every symbol that
is defined in the packages that define `modules` or is indexed in `pkgindex`.
"""
struct ModuleReference <: Rewriter
    info::ModuleInfo.PackageIndex
    ids::Set{String}
end

ModuleReference(pkgindex::ModuleInfo.PackageIndex) = ModuleReference(pkgindex, Set{String}())

function ModuleReference(ms; kwargs...)
    ModuleReference(PackageIndex(ms; kwargs...))
end


# TODO: make autoreload with Revise.jl

function Base.show(io::IO, mr::ModuleReference)
    print(io, "ModuleReference(")
    show(io, mr.info.modules.id)
    print(io, ", ")
    show(io, mr.info)
    print(io, ")")
end

function createsources!(rewriter::ModuleReference)
    sources = Dict{String, Node}()
    for symbolinfo in ModuleInfo.getsymbols(rewriter.info)
        docid = __get_ref_docid(rewriter.info, symbolinfo)
        docid in rewriter.ids && continue
        sources[docid] = __make_reference_file(rewriter.info, symbolinfo)
        push!(rewriter.ids, docid)
    end
    return sources
end

function __get_ref_docid(I::ModuleInfo.PackageIndex, symbol::ModuleInfo.SymbolInfo)
    shortid = symbol.id[(length(symbol.module_id) + 2):end]
    "$(ModuleInfo.getid(ModuleInfo.getpackage(I, symbol)))/ref/$(symbol.module_id).$shortid"
end

function __make_reference_file(I::PackageIndex, symbol::ModuleInfo.SymbolInfo)
    children = [__parse_docstring(d)
                for d in ModuleInfo.getdocstrings(I, symbol_id = symbol.id)]
    attributes = Dict{Symbol, Any}(:symbol_id => symbol.id, :title => symbol.name,
                              :module_id => symbol.module_id, :kind => symbol.kind,
                              :package_id => ModuleInfo.getid(ModuleInfo.getpackage(I, symbol)))
    if symbol.kind != :module
        # todo: change
        attributes[:public] = true
        attributes[:methods] = ModuleInfo.getmethods(I, symbol_id = symbol.id)
    end
    return Node(; tag=:documentation, children, attributes)
end

function __parse_docstring(doc::ModuleInfo.DocstringInfo)::Node
    node = parse(doc.docstring, MarkdownFormat())
    return Node(tag = :docstring, children = Node[node],
                attributes = Dict{Symbol, Any}(:module => doc.module_id,
                                               :symbol => doc.symbol_id,
                                               :file => doc.file,
                                               :line => doc.line))
end
