
#=
This file implements `ResolveReferences`, a `Rewriter` that searches documents for
links and resolves them. The file contains:

- a design discussion that explains what kinds of links we want to support
- an abstraction for defining rules to match and parse links ([`AbstractLinkRule`](#),
    [`parselink`](#), [`resolvelink`](#)); and
- a [`Rewriter`](#) [`ResolveReferences`](#) that uses a list of rules to resolve links in
    a project's documents

---

Links (by default identified as `:a` nodes with a `:href`
attribute) broadly fall into two categories:

- **external** links that point to external resources like a website. For example,
    `https://github.com` is the href for an external link.
- **internal** links that point to a document. These can point to Markdown documents,
    but also source files and module symbols.

Most of the complexity comes from resolving these internal links, which we will focus
on in the following.

## Kinds of links

Let's start with an example to gather some use cases for the kinds of linking we want to
support: _From a document written in Markdown, we want to link to a markdown file stored in
the same directory._

Now, if we want to support relative links, it's clear we need to take the context of the
link into account.

Consider the file that contains the link is stored in the project's root directory at
`docs/tutorial1.md` and we want it to link to `docs/tutorial2.md`. The simplest way to
link to it is with the href `"./tutorial2.md"`, which includes the relative path.

We also want to be able to use an absolute path to refer to a document. For example, from
markdown file, we may want to link with the README (stored in the project root) with the
href `"/README.md"`.

Using relative and absolute file paths, we can resolve links between documents of the same
kind, but we want to do more:

- Markdown files should link to relevant module symbols
- Module references should link to source files
- What if we want to link to documents in a different project?
- What about a document from a previous version?

## Link format

To make all of these possible, let's define a verbose, but explicit and unambiguous
link syntax that defines each of these parameters and then see how some parts can
be omitted based on context. Let's consider the example above and say that it is a file
in Pollen.jl and from the package version 0.2.0. We can uniquely link to it with:

> `Pollen@0.2.0/doc/docs/tutorial1.md`

In the abstract, the format is

> `${Package}@${Version}/${Document type}/${documentId...}`

Now, based on context of the source and target document, we can omit parameters:

- If we want to the latest version of a target document, we can omit the version:
    `"Pollen/doc/docs/tutorial1.md"`
- If the target document is contained in the same package, we can omit the package:
    `"/doc/docs/tutorial1.md"`
- If the target document has the same document type, we can omit that as well:
    - using an absolute link: `"/docs/tutorial1.md"`; or
    - a relative link: `"./tutorial2.md`", based on the path of the source document

Just some more examples:

- _Linking from a symbol docstring to a relevant tutorial_: The source document here has the
    `"ref"` document type so to link to a tutorial written in Markdown, which has a `"doc"`
    document type, we need to adress it with:

    > `"/doc/docs/tutorial1.md"`

    Note that we can omit the package name when the target is part of the
    same package.

## Implementation

Now we can get to defining rules for resolving links. A `LinkRule` will take in a
link href and other context, and

- in `parselink`, check whether the rule matches the link and parse it
- in `resolvelink`, take the parsed link and return a new `Node` that is inserted into
    a document

=#

"""
    LinkInfo(href, title, id, node, path, package, mod)

Container that stores information on a link in a document



    LinkInfo()


"""
Base.@kwdef struct LinkInfo
    # link target href
    href::String
    # link text
    title::String
    # document id of the source document
    id::String
    # the node in the document defining the link
    node::Node
    # (project root-relative) file path of the source document
    path::Union{String, Nothing} = nothing
    # package (versioned) the document is part of
    package::String
    # the module that a reference is part of
    mod::Union{Nothing, String} = nothing
end

"""
    abstract type AbstractLinkRule


## Extending

A rule `R` must implement the following methods:

- [`parselink`](#)`(::R, ::LinkInfo) -> String | Nothing` checks whether the rule applies
    to the link, returning a target if it does, or `nothing` otherwise
- [`resolvelink`](#)`(::R, ::LinkInfo, target)` takes a parsed target and returns a new
    `Node` that replaces the original link node.
"""
abstract type AbstractLinkRule end

"""
    parselink(rule::AbstractLinkRule, link::LinkInfo)
    parselink(rules::AbstractLinkRule, link::LinkInfo)
"""
function parselink end

"""
    resolvelink(rule, link::LinkInfo) -> Node | Nothing
    resolvelink(rules, link::LinkInfo) -> Node | Nothing
"""
function resolvelink end

#=
If a rule does not match a given link, `parselink` should return `nothing`. The high-level
call will use `parselink` to see if the rule matches.
=#

function resolvelink(rule::AbstractLinkRule, link::LinkInfo)
    target = parselink(rule, link)
    if isnothing(target)
        return link.node
    else
        return resolvelink(rule, link, target)
    end
end

#=
We can match a link against several rules, returning the result of the first rule
that matched (i.e. successfully parsed) it:
=#

function resolvelink(rules::AbstractVector{<:AbstractLinkRule}, link::LinkInfo)
    for rule in rules
        target = parselink(rule, link)
        if !isnothing(target)
            return resolvelink(rule, link, target)
        end
    end
    # if no rules match, return the original node
    return link.node
end

# Before we start defining the rules, let's implement a helper that lets us easily construct
# [`LinkInfo`](#)s from a link in a document.

function LinkInfo(node::Node; id = "NULL/", href = get(attributes(node), :href, ""),
                  title = gettext(node),
                  path = nothing, mod = nothing, package = first(splitpath(id)), attrs...)
    return LinkInfo(; package, id, href, title, path, mod, node)
end

#=

### External link rule

The first rule will find links to external URLs.
=#

struct URLLinkRule <: AbstractLinkRule end

function parselink(::URLLinkRule, link::LinkInfo)
    if startswith(link.href, "https://") || startswith(link.href, "http://")
        return link.href
    end
end

function resolvelink(::URLLinkRule, link::LinkInfo, target)
    return withattributes(link.node, merge(attributes(link.node), Dict(:href => target)))
end

@testset "URLLinkRule [AbstractLinkRule]" begin
    resolve(info) = parselink(URLLinkRule(), info)

    makeinfo(href) = LinkInfo(href, "title", "", Node(:o), "file.md", "", nothing)
    @test resolve(makeinfo("https://github.com")) isa String
    @test resolve(makeinfo("./doc")) isa Nothing
    @test resolve(makeinfo("httpdoc")) isa Nothing

    res = resolvelink(URLLinkRule(),
                      LinkInfo(Node(:a, "Text"; href = "https://github.com")))
    @test res == Node(:a, "Text"; href = "https://github.com")
end

#=

### Internal link rule

Next, we implement the rule that matches internal links to documents. See the above
discussion that explains the link format that we're parsing here. It will always resolve
a link, unless the link target is empty.
=#

Base.@kwdef struct InternalLinkRule <: AbstractLinkRule
    doctypes = ("src", "doc", "ref")
end

function parselink(rule::InternalLinkRule, link::LinkInfo)
    # TODO: add support for href syntax with (trailing) id, e.g."README.md/#Setup"
    # that link to headings. Similarly support automatic header syntax using "@ref"
    isempty(link.href) && return nothing
    parts = splitpath(link.href)
    if parts[1] == "/"
        length(parts) == 1 && return nothing
        if parts[2] in rule.doctypes
            # doc type is specified
            return "$(link.package)$(link.href)"
        else
            # doc type not specified -> same as source document
            doctype = split(link.id, '/')[2]
            return "$(link.package)/$(doctype)$(link.href)"
        end
    elseif contains(parts[1], '@')
        # package with version -> complete document ID
        return link.href
    else
        # relative link (doesn't start with '/')
        srcparts = split(link.id, '/')
        doctype = srcparts[2]
        srcpath = joinpath([".", srcparts[3:(end - 1)]...])
        path = normpath(joinpath(srcpath, link.href))
        # must not go outside folder
        startswith(path, "..") && return nothing
        return "$(link.package)/$(doctype)/$path"
    end
end

function resolvelink(::InternalLinkRule, link::LinkInfo, target)
    return withattributes(withtag(link.node, :reference),
                          merge(attributes(link.node),
                                Dict(:document_id => target)))
end

@testset "InternalLinkRule [AbstractLinkRule]" begin
    resolve(info) = parselink(InternalLinkRule(), info)
    # full link
    @test resolve(LinkInfo("Pollen@0.1.0/doc/README.md", "", "", Node(:null), nothing, "",
                           nothing)) ==
          "Pollen@0.1.0/doc/README.md"
    # doc type given, package omitted
    @test resolve(LinkInfo("/doc/README.md", "", "", Node(:null), nothing, "Pollen@0.1.0",
                           nothing)) ==
          "Pollen@0.1.0/doc/README.md"
    # doc type omitted, package omitted
    @test resolve(LinkInfo("/README.md", "", "Pkg@1/doc/bla.md", Node(:null), nothing,
                           "Pollen@0.1.0",
                           nothing)) == "Pollen@0.1.0/doc/README.md"
    # only relative path given
    @test resolve(LinkInfo("README.md", "", "Pkg@1/doc/bla.md", Node(:null), nothing,
                           "Pollen@0.1.0",
                           nothing)) == "Pollen@0.1.0/doc/README.md"
    @test resolve(LinkInfo("../README.md", "", "Pkg@1/doc/folder/bla.md", Node(:null),
                           nothing,
                           "Pollen@0.1.0", nothing)) == "Pollen@0.1.0/doc/README.md"

    # Cases where link is not resolvable
    # empty link target
    @test resolve(LinkInfo("", "", "", Node(:null), nothing, "", nothing)) isa Nothing
    @test resolve(LinkInfo("/", "", "", Node(:null), nothing, "", nothing)) isa Nothing
    # relative link going above root folder
    @test resolve(LinkInfo("../../README.md", "", "Pkg@1/doc/bla.md", Node(:null), nothing,
                           "Pollen@0.1.0", nothing)) isa Nothing

    @test resolvelink(InternalLinkRule(),
                      LinkInfo(Node(:a, "Title", href = "Pollen@0.1.0/doc/README.md"))) ==
          Node(:reference, "Title", document_id = "Pollen@0.1.0/doc/README.md",
               href = "Pollen@0.1.0/doc/README.md")
end

#=
## Symbol reference rule

Another common use case for hyperlinks is to automatically reference symbols in a module by
their name.

**Syntax**: In Documenter.jl, you can write a Markdown link like ```[`serve`](@ref)```  and
and it will automatically find a `serve` symbol defined in relevant modules and link to its
documentation. Pollen.jl (and Publish.jl) also support the syntax ```[`serve`](#)```.
In these cases the symbol name will be taken from the link title; in some cases you want to
use a different link title, so the following forms are also valid:
```[link title](@ref serve)```/```[link title](# serve)```.

Here, we implement a link rule that finds these links. Resolving the symbols based on
relevant modules will be done later, in the rewriter that also modifies the documents.
=#

struct SymbolLinkRule <: AbstractLinkRule
    I::ModuleInfo.PackageIndex
    prefixes::Any
end

SymbolLinkRule(pkgindex) = SymbolLinkRule(pkgindex, ("@ref", "#"))

function parselink(rule::SymbolLinkRule, link::LinkInfo)
    parts = split(link.href, ' ')
    if parts[1] in rule.prefixes
        if length(parts) == 2
            # symbol is given in href
            return (; symbol = parts[2], mod = link.mod)
        else
            # symbol is given in link node content
            length(children(link.node)) == 1 || return nothing
            child = only(children(link.node))
            child isa Node || return nothing
            tag(child) == :code || return nothing

            return (; symbol = gettext(child), mod = link.mod)
        end
    end
end

function resolvelink(rule::SymbolLinkRule, link::LinkInfo, target)
    bindings = unique(b -> b.symbol_id, resolvesymbol(rule.I, target.symbol))
    if isempty(bindings)
        @debug "Could not resolve symbol link!" target link
        # return unmodified link node
        return link.node
    else
        if length(bindings) > 1
            @debug """Found multiple possible bindings for automatic hyperreference:
                    $([b.id => b.symbol_id for b in bindings]). Using `$(bindings[begin].symbol_id)`""" target
        end
        return Node(:reference, children(link.node),
                    merge(attributes(link.node),
                          Dict(:document_id => __id_from_binding(rule.I, bindings[1]),
                               :reftype => "symbol")))
    end
end

function resolvesymbol(pkgindex::PackageIndex, symbol::String, modules = nothing)
    if isnothing(modules)
        modules = pkgindex.modules[pkgindex.modules.id .== pkgindex.modules.parent].id
    end
    bindings = ModuleInfo.resolvebinding(pkgindex,
                                         modules,
                                         symbol)
    filter(b -> haskey(pkgindex.index.symbols, b.symbol_id), bindings)
end

function __id_from_binding(I::ModuleInfo.PackageIndex, binding::ModuleInfo.BindingInfo)
    symbol = ModuleInfo.getsymbol(I, binding)
    package = ModuleInfo.getpackage(I, symbol)
    return "$(package.name)@$(package.version)/ref/$(symbol.id)"
end

@testset "SymbolLinkRule [AbstractLinkRule]" begin
    resolve(info) = parselink(SymbolLinkRule(PackageIndex([Pollen])), info)
    @test resolve(LinkInfo(Node(:a, Node(:code, "sum"), href = "#"))).symbol ==
          "sum"
    @test resolve(LinkInfo(Node(:a, Node(:code, "sum"), href = "@ref"))).symbol ==
          "sum"
    @test resolve(LinkInfo(Node(:a, Node(:code, "sum"), href = ""))) isa Nothing
    @test resolve(LinkInfo(Node(:a, "the function", href = "# Pollen.serve"))).symbol ==
          "Pollen.serve"
    @test resolve(LinkInfo(Node(:a, "the function", href = ""))) isa Nothing
    @test resolve(LinkInfo(Node(:a, Node(:code, "sum"), href = "##"))) isa Nothing

    @test resolvelink(SymbolLinkRule(PackageIndex([Pollen])),
                      LinkInfo(Node(:a, Node(:code, "serve"), href = "#")),
                      (symbol = "serve", mod = "Pollen")) ==
          Node(:reference, Node(:code, "serve"),
               document_id = "Pollen@0.1.0/ref/Pollen.serve",
               href = "#", reftype = "symbol")
end

#=
## Rewriter

Now that we can parse links with rules and combine them, let's write a [`Rewriter`](#)
that uses these rules to resolve links in all of a [`Project`](#)'s documents.
=#

"""
    ResolveReferences()
    ResolveReferences(modules; selector)
    ResolveReferences(rules, selector)
"""
struct ResolveReferences <: Rewriter
    rules::Vector{<:AbstractLinkRule}
    selector::Selector
end

Base.show(io::IO, ::ResolveReferences) = print(io, "ResolveReferences()")

function ResolveReferences(pkgindex = nothing; selector = DEFAULT_LINK_SELECTOR,
                           prefixes = ("@ref", "#"))
    rules = if isnothing(pkgindex)
        [URLLinkRule(), InternalLinkRule()]
    else
        [URLLinkRule(), SymbolLinkRule(pkgindex, prefixes), InternalLinkRule()]
    end
    return ResolveReferences(rules, selector)
end

const DEFAULT_LINK_SELECTOR = SelectTag(:a) & SelectHasAttr(:href)

function rewritedoc(rewriter::ResolveReferences, docid, doc::Node)
    cata(doc, rewriter.selector) do node
        link = LinkInfo(node; id = docid, mod = get(attributes(doc), :module, nothing),
                        attributes(doc)...)
        resolvelink(rewriter.rules, link)
    end
end

function ResolveSymbols(pkgindex::PackageIndex)
    selector = SelectTag(:Identifier)
    rule = SymbolCodeRule(pkgindex)
    return ResolveReferences([rule], selector)
end

struct SymbolCodeRule <: AbstractLinkRule
    I::PackageIndex
end

function SymbolCodeRule(ms::Vector{Module}; kwargs...)
    SymbolCodeRule(PackageIndex(ms; recurse = 1, cache = true, kwargs...))
end

function parselink(rule::SymbolCodeRule, link::LinkInfo)
    @assert length(children(link.node)) == 1 && only(children(link.node)) isa Leaf{String}
    idparts = splitpath(link.id)
    mod = if length(idparts) >= 2 && idparts[2] == "src"
        split(idparts[begin], '@')[begin]
    else
    end
    return (identifier = only(children(link.node))[], mod = mod)
end

function resolvelink(rule::SymbolCodeRule, link::LinkInfo, target)
    modules = if !isnothing(target.mod)
        filter(m -> startswith(m.id, target.mod), rule.I.modules).id
    else
        nothing
    end
    bindings = resolvesymbol(rule.I, target.identifier, modules)
    if isempty(bindings)
        return link.node
    else
        return Node(:reference, children(link.node),
                    merge(attributes(link.node),
                          Dict(:document_id => __id_from_binding(rule.I, bindings[1]),
                               :reftype => "symbol")))
    end
end
