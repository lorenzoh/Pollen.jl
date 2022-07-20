
#=
This file implements `ResolveReferences`, a `Rewriter` that searches documents for
links and resolves them. Links (by default identified as `:a` nodes with a `:href`
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
link href and other context, and return a resolved `LinkType`.

=#


abstract type LinkType end
struct UnresolvedLink <: LinkType end

Base.@kwdef struct LinkInfo
    # link target href
    href::String
    # link text
    title::String
    # document id of the source document
    id::String
    # (project root-relative) file path of the source document
    path::Union{String, Nothing} = nothing
    # package (versioned) the document is part of
    package::String
    # the module that a reference is part of
    mod::Union{Nothing, String}
end


abstract type AbstractLinkRule end


"""
    resolvelink(rule::AbstractLinkRule, link::LinkInfo)
    resolvelink(rules::AbstractLinkRule, link::LinkInfo)
"""
function resolvelink end

#=
If a rule does not match a given link, it should return [`UnresolvedLink`](#). We can
match a link against several rules, returning the result of the first rule that matched it:
=#

function resolvelink(rules::AbstractVector{<:AbstractLinkRule}, link::LinkInfo)
    for rule in rules
        res = resolvelink(rule, link)
        res isa UnresolvedLink || return res
    end
    return UnresolvedLink()
end

# Before we start defining the rules, let's implement a helper that lets us easily construct
# [`LinkInfo`](#)s from a link in a document.

function LinkInfo(id::String, doc::Node, title, href)
    package = first(splitpath(id))
    path = get(attributes(doc), :path, nothing)
    mod = get(attributes(doc), :module, nothing)
    return LinkInfo(; package, id, href, title, path, mod)
end

#=

### External link rule

The first rule will find links to external URLs.
=#

struct URLLink <: LinkType
    href::String
end
struct URLLinkRule <: AbstractLinkRule end

function resolvelink(::URLLinkRule, link::LinkInfo)
    if startswith(link.href, "https://") || startswith(link.href, "http://")
        return URLLink(link.href)
    else
        return UnresolvedLink()
    end
end

# _

const DEFAULT_LINK_SELECTOR = SelectTag(:a) & SelectHasAttr(:href)

Base.@kwdef struct ResolveLinks <: Rewriter
    selector = DEFAULT_LINK_SELECTOR
end
