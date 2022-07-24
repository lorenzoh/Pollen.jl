
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
If a rule does not match a given link, `parselink` should return `nothing`. We can
match a link against several rules, returning the result of the first rule that matched it:
=#

function resolvelink(rules::AbstractVector{<:AbstractLinkRule}, link::LinkInfo, node::Node)
    for rule in rules
        target = parselink(rule, link)
        if !isnothing(target)
            return resolvelink(rule, link, target)
        end
    end
    # if no rules match, return the original node
    return node
end

# Before we start defining the rules, let's implement a helper that lets us easily construct
# [`LinkInfo`](#)s from a link in a document.

function LinkInfo(id::String, doc::Node, node)
    package = first(splitpath(id))
    href = get(attributes(node), :href, "")
    title = gettext(node)
    path = get(attributes(doc), :path, nothing)
    mod = get(attributes(doc), :module, nothing)
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
    @test resolve(LinkInfo("https://github.com", "Github", "", nothing, "", nothing)) isa String
    @test resolve(LinkInfo("./doc", "", "", nothing, "", nothing)) isa Nothing
    @test resolve(LinkInfo("httpdoc", "", "", nothing, "", nothing)) isa Nothing

    res = resolvelink(URLLinkRule(), Node(:a, "Text"), "https://github.com")
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
        srcpath = joinpath([".", srcparts[3:end-1]...])
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
    @test resolve(LinkInfo("Pollen@0.1.0/doc/README.md", "", "", nothing, "", nothing)) == "Pollen@0.1.0/doc/README.md"
    # doc type given, package omitted
    @test resolve(LinkInfo("/doc/README.md", "", "", nothing, "Pollen@0.1.0", nothing)) == "Pollen@0.1.0/doc/README.md"
    # doc type omitted, package omitted
    @test resolve(LinkInfo("/README.md", "", "Pkg@1/doc/bla.md", nothing, "Pollen@0.1.0", nothing)) == "Pollen@0.1.0/doc/README.md"
    # only relative path given
    @test resolve(LinkInfo("README.md", "", "Pkg@1/doc/bla.md", nothing, "Pollen@0.1.0", nothing)) == "Pollen@0.1.0/doc/README.md"
    @test resolve(LinkInfo("../README.md", "", "Pkg@1/doc/folder/bla.md", nothing, "Pollen@0.1.0", nothing)) == "Pollen@0.1.0/doc/README.md"

    # Cases where link is not resolvable
    # empty link target
    @test resolve(LinkInfo("", "", "", nothing, "", nothing)) isa Nothing
    @test resolve(LinkInfo("/", "", "", nothing, "", nothing)) isa Nothing
    # relative link going above root folder
    @test resolve(LinkInfo("../../README.md", "", "Pkg@1/doc/bla.md", nothing, "Pollen@0.1.0", nothing)) isa Nothing

    @test resolvelink(InternalLinkRule(), Node(:a, "Title"), "Pollen@0.1.0/doc/README.md"
        ) == Node(:reference,"Title", document_id="Pollen@0.1.0/doc/README.md")
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
    prefixes
end

function SymbolLinkRule(ms; prefixes = ("#", "@ref"))
    SymbolLinkRule(PackageIndex(ms, verbose = true, cache = true), prefixes)
end


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
            if child isa Node && tag(child) === :code
                return (; symbol = gettext(link.node), mod = link.mod)
            end
        end
    end
end

function resolvelink(rule::SymbolLinkRule, link::LinkInfo, target)
    refid = __resolveidentifier(rule.I, target.symbol, target.mod)
    if isnothing(refid)
        @warn "Could not resolve symbol link!" target link
        return link.node
    else
        title = gettext(link.node)
        return Node(:reference, XTree[Leaf(title)], merge(attributes(link.node),
                                    Dict(:document_id => refid)))
    end
end


function __resolveidentifier(I::ModuleInfo.PackageIndex, identifier, m)
    deps = if m isa String
        pkg = ModuleInfo.getpackage(I, ModuleInfo.getmodule(I, m))
        deps = Set(pkg.dependencies)
        push!(deps, m)
        deps
    else
        deps = 1
    end
    name = identifier
    i = findfirst(s -> s.module_id in deps && s.name == name, I.symbols)
    isnothing(i) && return nothing
    return "$(ModuleInfo.getid(pkg))/ref/$(I.symbols.id[i])"
end



@testset "SymbolLinkRule [AbstractLinkRule]" begin
    resolve(info) = parselink(SymbolLinkRule([Pollen]), info)
    @test resolve(LinkInfo("#", "`sum`", "", nothing, "", nothing)).symbol == "sum"
    @test resolve(LinkInfo("@ref", "`sum`", "", nothing, "", nothing)).symbol == "sum"
    @test resolve(LinkInfo("#", "sum", "", nothing, "", nothing)) isa Nothing
    @test resolve(LinkInfo("# sum", "bla", "", nothing, "", nothing)).symbol == "sum"
    @test resolve(LinkInfo("@ref Pollen.serve", "bla", "", nothing, "", nothing)).symbol == "Pollen.serve"
    @test resolve(LinkInfo("", "bla", "", nothing, "", nothing)) isa Nothing
    @test resolve(LinkInfo("##", "bla", "", nothing, "", nothing)) isa Nothing

    @test resolvelink(SymbolLinkRule([Pollen]), Node(:a, "`serve`", href = "#"), (symbol = "serve", mod = "Pollen")
        ) == Node(:reference,"serve", document_id="Pollen@0.1.0/ref/Pollen.serve", href = "#")
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

function ResolveReferences(ms = []; selector = DEFAULT_LINK_SELECTOR)
    rules = if isempty(ms)
        [URLLinkRule(), InternalLinkRule()]
    else
        [URLLinkRule(), SymbolLinkRule(ms), InternalLinkRule()]
    end
    return ResolveReferences(rules, selector)
end

const DEFAULT_LINK_SELECTOR = SelectTag(:a) & SelectHasAttr(:href)


function rewritedoc(rewriter::ResolveReferences, docid, doc::Node)
    cata(doc, rewriter.selector) do node
        link = LinkInfo(docid, doc, node)
        node_ = resolvelink(rewriter.rules[1:2], link, node)
    end
end
