
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


function ModuleReference(pkgindex::ModuleInfo.PackageIndex)
    ModuleReference(pkgindex, Set{String}())
end

function ModuleReference(ms; kwargs...)
    ModuleReference(PackageIndex(ms; kwargs...))
end

# TODO: make autoreload with Revise.jl

function Base.show(io::IO, mr::ModuleReference)
    print(io, "ModuleReference(")
    show(io, mr.info.modules.id)
    print(io, ")")
end

# Loading from config

@option struct ConfigModuleReference <: AbstractConfig
    index::ConfigPackageIndex = ConfigPackageIndex()
end
configtype(::Type{ModuleReference}) = ConfigModuleReference


function from_config(config::ConfigModuleReference)
    index = from_config(config.index)
    ModuleReference(index)
end



function createsources!(rewriter::ModuleReference)
    sources = Dict{String, Node}()
    for symbolinfo in ModuleInfo.getsymbols(rewriter.info)
        docid = "ref/$(symbolinfo.id)"
        docid in rewriter.ids && continue
        sources[docid] = __make_reference_file(rewriter.info, symbolinfo)
        push!(rewriter.ids, docid)
    end
    return sources
end


function __make_reference_file(I::PackageIndex, symbol::ModuleInfo.SymbolInfo)
    children = [__parse_docstring(d)
                for d in ModuleInfo.getdocstrings(I, symbol_id = symbol.id)]
    attributes = Dict{Symbol, Any}(:symbol_id => symbol.id, :title => symbol.name,
                                   :module_id => symbol.module_id, :kind => symbol.kind,
                                   :package_id => ModuleInfo.getid(ModuleInfo.getpackage(I,
                                                                                         symbol)))
    if symbol.kind != :module
        # TODO: change
        binding = ModuleInfo.getbinding(I, symbol.id)
        attributes[:exported] = isnothing(binding) ? false : binding.exported
        attributes[:methods] = ModuleInfo.getmethods(I, symbol_id = symbol.id)
    elseif symbol.kind == :module
        # TODO: include submodules in attributes
        # TODO: include exported bindings in attributes
        pkgid = ModuleInfo.getid(ModuleInfo.getpackage(I, symbol))
        attributes[:symbols] = ModuleInfo.getsymbols(I, module_id = symbol.id)
        attributes[:files] = ModuleInfo.getfiles(I, package_id = pkgid)
    end
    return Node(; tag = :documentation, children, attributes)
end

function __parse_docstring(doc::ModuleInfo.DocstringInfo)::Node
    node = parse(doc.docstring, MarkdownFormat())
    return Node(tag = :docstring, children = Node[node],
                attributes = Dict{Symbol, Any}(
                    :module => doc.module_id,
                    :symbol => doc.symbol_id,
                    :file => doc.file,
                    :line => doc.line))
end
