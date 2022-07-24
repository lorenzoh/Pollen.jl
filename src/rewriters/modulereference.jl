
struct ModuleReference <: Rewriter
    ms::Vector{Module}
    info::ModuleInfo.PackageIndex
    ids::Set{String}
end

function ModuleReference(ms)
    ModuleReference(ms, PackageIndex(ms, verbose = true, cache = true), Set{String}())
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
    "$(ModuleInfo.getid(ModuleInfo.getpackage(I, symbol)))/ref/$shortid"
end

function __make_reference_file(I::PackageIndex, symbol::ModuleInfo.SymbolInfo)
    children = map(__parse_docstring, ModuleInfo.getdocstrings(I, symbol_id = symbol.id))
    attrs = Dict{Symbol, Any}(:symbol_id => symbol.id, :title => symbol.name,
                              :module => symbol.module_id)
    return Node(:documentation, children, attrs)
end

function __parse_docstring(doc::ModuleInfo.DocstringInfo)
    node = parse(doc.docstring, MarkdownFormat())
    return Node(:docstring, Node[node],
                Dict{Symbol, Any}(:module => doc.module_id, :symbol => doc.symbol_id, :file => doc.file,
                     :line => doc.line))
end
