#=
This file defines the [`Rewriter`](#) abstract type and all functions that form its
interface.
=#

"""
    abstract type Rewriter

Pluggable extension to a [`Project`](#) with hooks to transform
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

#=
## Project lifecycle interfaces

Below we define the interface for `Rewriter`s to interact with the [`Project`](#) lifecycle.
=#

"""
    rewritedoc(rewriter, docid, document) -> document'

Rewrite `document` with id `docid`, returning a rewritten document.

`rewritedoc` is called in a [`Project`](#)'s lifecycle on a document whenever it is first
created or updated. If left undefined for a [`Rewriter`](#), it defaults to returning the
`document` unmodified.
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

"""
    createsources!(rewriter)

Allows a [`Rewriter`](#) to add new files to a project by returning a `Dict` of pairs
`docid::String => document::Node`.

This should be stateful, i.e. calling it multiple times should not return the same
documents.
"""
createsources!(::Rewriter) = Dict{String, Node}()

#=
## Loading interfaces

So that `Rewriter`s can be configured and instantiated with JSON/YAML-like configuration
files, we define two functions:

- `from_config(::Type{R<:Rewriter}, config) -> R` creates an instance of a rewriter
- `default_config(::Type{R<:Rewriter}) -> Dict` creates default values that can be passed
    to `from_config`.
=#

"""
    configtype(T)

Return the `Configurations` option type for type `T`.
"""
function configtype end

abstract type AbstractConfig end

Base.show(io::IO, c::AbstractConfig) = PrettyPrint.pprint(io, c)

"""
    from_config(Rewriter, rewriter_config, project_config, state)
"""
from_config(T::Type, config::Dict{String}) = from_config(T, from_dict(configtype(T), config))

function merge_configs(config::C, d::Dict) where C
    from_dict(C, merge_config_dicts(C, shallow_dict(config), d))
end

shallow_dict(cfg::C) where C = Dict(zip(map(string, fieldnames(C)), map(Base.Fix1(getfield, cfg), fieldnames(C))))

function merge_config_dicts(C::Type{<:AbstractConfig}, d1, d2)
    dst = Dict{String, Any}()
    for (name, T) in zip(map(string, fieldnames(C)), fieldtypes(C))
        if haskey(d1, name) && haskey(d2, name)
            dst[name] = if d1[name] isa AbstractConfig
                merge_configs(d1[name], shallow_dict(d2[name]))
            else
                mergerec(d1[name], d2[name])
            end
        elseif haskey(d2, name)
            dst[name] = d2[name]
        elseif haskey(d1, name)
            dst[name] = d1[name]
        end
    end
    return from_dict(C, dst)
end

mergerec(d1::AbstractDict, d2::AbstractDict) = mergewith(mergerec, d1, d2)
mergerec(x1, x2) = x2

#=
## Example `Rewriter`

Below we define a very simple `Rewriter`. In every document, it applies a function `fn` to
every node/leaf matching a `selector` using [`cata`](#).
=#
struct Replacer <: Rewriter
    fn::Any
    selector::Selector
end

Base.show(io::IO, replacer::Replacer) = print(io, "Replacer($(replacer.selector))")

function rewritedoc(replace::Replacer, docid, doc::XTree)
    return cata(replace.fn, doc, replace.selector)
end
