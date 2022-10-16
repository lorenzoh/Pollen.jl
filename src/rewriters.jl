
"""
    abstract type Rewriter

Pluggable extension to a [`Project`] with hooks to transform
individual documents, create new documents, register file update
handlers and perform additional build steps.

See the following methods:
- [`rewritedoc`](#) is applied to every source document and returns a
    modified document that is passed to the next rewriter.
- [`createsources!`](#) allow rewriters to create new source documents
- [`reset!`](#)
- [`postbuild`](#)
"""
abstract type Rewriter end

"""
    rewritedoc(rewriter, docid, document) -> document'

Rewrite `document` with id `docid`, returning a rewritten document.
"""
function rewritedoc(::Rewriter, docid, doc)
    return doc
end

"""
    reset!(rewriter)

Clears internal state of `rewriter`. Does nothing if not overwritten.
"""
function reset!(::Rewriter) end

"""
    postbuild(rewriter, project, dst, format)

Post-build callback for [`Rewriter`](#)s.
"""
function postbuild(::Rewriter, project, builder) end

createsources!(::Rewriter) = Dict{String, Node}()

struct Replacer <: Rewriter
    fn::Any
    selector::Selector
end

Base.show(io::IO, replacer::Replacer) = print(io, "Replacer($(replacer.selector))")

function rewritedoc(replace::Replacer, docid, doc::XTree)
    return cata(replace.fn, doc, replace.selector)
end
