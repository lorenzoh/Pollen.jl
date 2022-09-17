module Pollen

using ANSIColoredPrinters
using AbstractTrees
using Base.Docs
import Crayons: @crayon_str
import CommonMark as CM
import Base64: Base64EncodePipe
import JuliaSyntax
using CSTParser
using DataFrames
using FilePathsBase
using DataStructures: DefaultDict, OrderedDict
import Gumbo
import Glob: glob
using InlineTest
using JuliaFormatter
using Graphs
using MetaGraphs
using Mustache
using LiveServer
import LiveServer
using TOML
using IOCapture
using ModuleInfo
using InlineTest
using JSON3
using ThreadSafeDicts
import Random
using Revise
import Git
import PkgTemplates
import PkgTemplates: @plugin, @with_kw_noshow, Template, Plugin,
                     hook, getplugin, with_project, render_file, gen_file
using Pkg
using Scratch
using NodeJS

# We first define [`Node`](#)s and [`Leaf`](#)s, the data structure that underpins
# the rest of the library. We also define selectors to find parts of a tree.
# Additionally, catamorphisms can be used to functionally transform these trees.

include("xtree/xtree.jl")
include("xtree/selectors.jl")
include("xtree/catamorphisms.jl")
include("xtree/folds.jl")

include("files.jl")

# So that we can represent data from different formats as a tree, we define
# [`Format`](#)s that allow reading and/or writing from and to different
# file formats.

include("formats/format.jl")
include("formats/_ijulia_display.jl")
include("formats/markdown.jl")
include("formats/json.jl")
include("formats/juliasyntax.jl")
include("formats/html.jl")
include("formats/jupyter.jl")

export MarkdownFormat, JSONFormat, HTMLFormat, JuliaSyntaxFormat, JupyterFormat

include("rewriters.jl")
include("project.jl")
include("builders.jl")

include("serve/events.jl")
include("serve/filewatching.jl")
include("serve/server.jl")
include("serve/servefiles.jl")

include("rewriters/documentfolder.jl")
include("rewriters/sourcefiles.jl")
include("rewriters/modulereference.jl")
include("rewriters/basic.jl")
include("rewriters/coderunner.jl")
include("rewriters/packagewatcher.jl")
include("rewriters/parsecode.jl")
include("rewriters/parseansi.jl")
#include("rewriters/references.jl")
include("rewriters/resolvereferences.jl")
include("rewriters/backlinks.jl")
include("rewriters/searchindex.jl")
include("rewriters/saveattributes.jl")
include("rewriters/docversions.jl")
#include("rewriters/loadfrontendconfig.jl")
include("rewriters/staticresources.jl")

FRONTENDDIR = ""

function __init__()
    global FRONTENDDIR = @get_scratch!("frontend")
end

include("documentation/docstyles.jl")

include("frontend.jl")
include("docs.jl")
include("pkgtemplate.jl")

export select, selectfirst,
       XTree, Node, Leaf,
       cata, catafirst, replace, replacefirst, fold, catafold, children,
       SelectNode, withtag,
       Replacer, Inserter, HTMLTemplater, ExecuteCode,
       NthChild, FirstChild, Before, After,
       Project, build, FileBuilder,
       SelectTag, SelectLeaf, SelectOr, XExpr, ChangeTag, htmlify,
       AddTableOfContents, SelectAttrEq,
       Selector, resolveidentifier, serve,
# rewriters
       AddID, HTMLify, ChangeLinkExtension, FormatCode, AddTableOfContents, Referencer,
       DocumentFolder,
       documentationproject, Server, runserver, ServeFiles, ServeFilesLazy,
       PackageWatcher, StaticResources, ParseCode, PackageDocumentation,
       RelativeLinks, Backlinks, SearchIndex, SaveAttributes, LoadFrontendConfig,
       ResolveReferences,

       PackageIndex

end
