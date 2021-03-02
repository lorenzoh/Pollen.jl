module Pollen

using AbstractTrees
using Base.Docs
using CommonMark
using CommonMark: Document, Item, Text, Paragraph, List, Heading,
    Emph, SoftBreak, Link, Code, Node, AbstractContainer, CodeBlock, ThematicBreak,
    BlockQuote
using FileTrees
using FilePathsBase
using DataStructures: DefaultDict
import Gumbo
using Mustache


include("xexpr.jl")
include("reflectionutils.jl")
include("select.jl")
include("transforms/transforms.jl")
include("references.jl")

include("formats.jl")
include("markdown.jl")
include("files.jl")
include("html.jl")
include("build.jl")
include("rewriters.jl")
include("rewriters/referencer.jl")
include("rewriters/documenttree.jl")
include("project.jl")



export select,
    SelectTag, SelectOr, XExpr, ChangeTag, htmlify, AddSlugID, AddTableOfContents,
    Selector, xexpr, parse, HTML, Markdown, resolveidentifier, parsefiletree

end
