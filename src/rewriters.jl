
"""
    abstract type Rewriter

Pluggable extension to a [`Project`] with hooks to transform
individual documents, create new documents, register file update
handlers and perform additional build steps.

See the following methods:
- [`rewritedoc`](#)
- [`createdocs`](#)
- [`reset!`](#)
- [`postbuild`](#)
- [`getfilehandlers`](#)
"""
abstract type Rewriter end

"""
    rewritedoc(rewriter, p, doc) -> doc'

Rewrite `doc` at path `p`. Return rewritten `doc`.
"""
function rewritedoc(rewriter::Rewriter, p, doc)
    return doc
end


"""
    reset!(rewriter)

Clears internal state of `rewriter`. Does nothing if not overwritten.
"""
function reset!(rewriter::Rewriter) end


"""
    postbuild(rewriter, project, dst, format)

Post-build callback for [`Rewriter`](#)s.
"""
function postbuild(rewriter, project, builder) end


createsources!(::Rewriter) = Dict{AbstractPath, XTree}()


struct Replacer <: Rewriter
    fn
    selector::Selector
end

Base.show(io::IO, replacer::Replacer) = print(io, "Replacer($(replacer.selector))")

function rewritedoc(replace::Replacer, p::AbstractPath, doc::XTree)
    return cata(replace.fn, doc, replace.selector)
end
