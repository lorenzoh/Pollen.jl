module Pollen

using AbstractTrees
using Base.Docs
using CommonMark
using CommonMark: Document, Item, Text, Paragraph, List, Heading,
    Emph, SoftBreak, Link, Code, Node, AbstractContainer, CodeBlock, ThematicBreak,
    BlockQuote, Admonition, Attributes, Image, Citation
using FilePathsBase
using DataStructures: DefaultDict, OrderedDict
import Gumbo
using JuliaFormatter
using Mustache
using LiveServer
using IJulia
import LiveServer
using HTTP
using TOML
using IOCapture: capture
using JSON3
using Revise


include("xtree.jl")
include("selectors.jl")
include("catas.jl")
include("folds.jl")

#include("xexpr.jl")
include("reflectionutils.jl")
include("references.jl")
include("files.jl")

include("formats.jl")
include("markdown.jl")
include("html.jl")
include("jupyter.jl")

include("rewriters.jl")
include("project.jl")
include("builders.jl")

include("serve/events.jl")
include("serve/server.jl")
include("serve/servefiles.jl")

include("rewriters/documentfolder.jl")
include("rewriters/referencer.jl")
include("rewriters/documenttree.jl")
include("rewriters/basic.jl")
include("rewriters/assets.jl")
include("rewriters/templater.jl")
include("rewriters/coderunner.jl")
include("rewriters/inserter.jl")
include("rewriters/toc.jl")
include("rewriters/packagewatcher.jl")

include("serve.jl")
include("servelazy.jl")
include("projects.jl")



export select,
    XTree, XNode, XLeaf,
    cata, catafirst, replace, replacefirst, fold, catafold,
    SelectNode,
    Replacer, Inserter, HTMLTemplater, ExecuteCode,
    NthChild, FirstChild, Before, After,
    Project, build,
    SelectTag, SelectOr, XExpr, ChangeTag, htmlify, AddSlugID, AddTableOfContents, SelectAttrEq,
    Selector, parse, HTML, Markdown, resolveidentifier, serve,
    # rewriters
    AddID, HTMLify, ChangeLinkExtension, FormatCode, AddTableOfContents, Referencer, DocumentFolder,
    documentationproject, Server, runserver, ServeFiles, ServeFilesLazy

end
