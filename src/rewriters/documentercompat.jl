struct DocumenterCompat <: Rewriter
    pkgindex::PackageIndex
end


function Pollen.rewritedoc(rewriter::DocumenterCompat, id, doc)
    # If "doc", remove leading :h1 Node


    # TODO: actually run doctests -> Make new rewriter
    doc = parse_jldoctests(doc)

    doc = parse_docs_blocks(doc, rewriter.pkgindex)
    return doc
end

# Load from config


@option struct ConfigDocumenterCompat <: AbstractConfig
    index::ConfigPackageIndex = ConfigPackageIndex()
end
configtype(::Type{DocumenterCompat}) = ConfigDocumenterCompat
from_config(config::ConfigDocumenterCompat) = DocumenterCompat(from_config(config.index))


# ## Helpers

function SelectDocTest()
    (SelectTag(:codeblock) &
     SelectHasAttr(:lang) &
     SelectCondition(node -> startswith(attributes(node)[:lang], "jldoctest")))
end

function parse_jldoctests(doc::Node)
    cata(doc, SelectDocTest()) do node
        doctest = join(split(attributes(node)[:lang], " ")[2:end], " ")
        withattributes(node, merge(attributes(node), Dict(:lang => "julia", :doctest => doctest)))
    end
end


SelectDocsBlock() = SelectTag(:codeblock) & SelectAttrEq(:lang, "@docs")

function parse_docs_blocks(doc::Node, pkgindex::PackageIndex)
    cata(doc, SelectDocsBlock()) do node
        lines = filter(!isempty, split(gettext(node), "\n"))
        entries = map(line -> split(line, "(")[begin], lines)
        docids = map(entries) do entry
            bindings = unique(ModuleInfo.resolvebinding(pkgindex, pkgindex.modules.id, string(entry)))
            if isempty(bindings)
                @info "Cannot resolve doc symbol `$entry`"
                nothing
            else
                docid = _get_binding_docid(pkgindex, bindings[1])
                if isnothing(docid)
                    @info "Cannot resolve doc symbol `$entry`"
                    nothing
                else
                    docid
                end
            end
        end

        refs = [Node(:reference, entry, document_id=docid, reftype=:symbol)
                    for (entry, docid) in zip(entries, docids) if !isnothing(docid)]
        Node(:docsblock, refs)
    end
end


function _get_binding_docid(pkgindex::PackageIndex, binding::ModuleInfo.BindingInfo)
    symbol = ModuleInfo.getentry(pkgindex, :symbols, binding.symbol_id)
    isnothing(symbol) && return
    module_ = ModuleInfo.getentry(pkgindex, :modules, symbol.module_id)
    isnothing(module_) ? nothing : "$(module_.package_id)/ref/$(binding.symbol_id)"
end
