module Pollen

using AbstractTrees
using Base.Docs
using CommonMark
using CommonMark: Document, Item, Text, Paragraph, List, Heading,
    Emph, SoftBreak, Link, Code, Node, AbstractContainer, CodeBlock, ThematicBreak,
    BlockQuote, Admonition, Attributes, Image, Citation
using FileTrees
using FilePathsBase
using DataStructures: DefaultDict
import Gumbo
using JuliaFormatter
using Mustache
using LiveServer
using IJulia
using LiveServer: SimpleWatcher, watch_file!, start, stop
using TOML
using IOCapture


include("xtree.jl")
include("selectors.jl")
include("catas.jl")
include("folds.jl")

#include("xexpr.jl")
include("reflectionutils.jl")
include("references.jl")

include("formats.jl")
include("markdown.jl")
include("files.jl")
include("html.jl")
include("rewriters.jl")
include("rewriters/referencer.jl")
include("rewriters/documenttree.jl")
include("rewriters/basic.jl")
include("rewriters/assets.jl")
include("rewriters/templater.jl")
include("rewriters/coderunner.jl")
include("rewriters/inserter.jl")
include("rewriters/toc.jl")

include("project.jl")
include("serve.jl")



export select,
    XTree, XNode, XLeaf,
    cata, catafirst, replace, replacefirst, fold, catafold,
    SelectNode,
    Replacer, Inserter, HTMLTemplater, ExecuteCode,
    NthChild, FirstChild, Before, After,
    Project,
    SelectTag, SelectOr, XExpr, ChangeTag, htmlify, AddSlugID, AddTableOfContents, SelectAttrEq,
    Selector, parse, HTML, Markdown, resolveidentifier, parsefiletree, serve,
    # rewriters
    AddID, HTMLify, ChangeLinkExtension, FormatCode, AddTableOfContents, Referencer

end
