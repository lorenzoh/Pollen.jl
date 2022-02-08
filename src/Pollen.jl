module Pollen

using ANSIColoredPrinters
using AbstractTrees
using Base.Docs
using CommonMark
using CSTParser
using DataFrames
using CommonMark: Document, Item, Text, Paragraph, List, Heading,
    Emph, SoftBreak, Link, Code, Node, AbstractContainer, CodeBlock, ThematicBreak,
    BlockQuote, Admonition, Attributes, Image, Citation
using FilePathsBase
using DataStructures: DefaultDict, OrderedDict
import Gumbo
using JuliaFormatter
using Graphs
using MetaGraphs
using Mustache
using LiveServer
using IJulia
import LiveServer
using HTTP
using TOML
using IOCapture
using ModuleInfo
using InlineTest
using JSON3
using Revise


include("xtree.jl")
include("selectors.jl")
include("catas.jl")
include("folds.jl")

include("reflectionutils.jl")
include("references.jl")
include("files.jl")

include("formats/format.jl")
include("formats/markdown.jl")
include("formats/html.jl")
include("formats/jupyter.jl")
include("formats/json.jl")
include("formats/julia.jl")
include("formats/juliacode.jl")
include("formats/cst.jl")

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
include("rewriters/parsecode.jl")

include("frontend/references.jl")
include("frontend/documentgraph.jl")
include("frontend/searchindex.jl")
include("frontend/saveattributes.jl")
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
    documentationproject, Server, runserver, ServeFiles, ServeFilesLazy,
    PackageWatcher,
    RelativeLinks

end
