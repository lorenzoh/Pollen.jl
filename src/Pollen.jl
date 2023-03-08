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
import FilePathsBase: FilePathsBase, AbstractPath, Path, @p_str, extension, absolute, filename, walkpath
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
using PkgTemplates: PkgTemplates, @plugin, @with_kw_noshow, Template, Plugin,
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

export Node, Leaf, children, tag, withtag, cata, catafirst, catafold,
       select, selectfirst, SelectTag, SelectOr, SelectNode, SelectLeaf, SelectAttrEq,
       SelectHasAttr

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

# To load and transform a corpus of documents, we gather them as part of a [`Project`](#)
# and compose [`Rewriter`](#)s to transform them.

include("rewriters.jl")
include("project.jl")
include("builders.jl")

export Project, FileBuilder

include("serve/events.jl")
include("serve/filewatching.jl")
include("serve/server.jl")
include("serve/servefiles.jl")

# Rewriters transform individual documents and can also modify project-level information.

include("rewriters/documentfolder.jl")
include("rewriters/checklinks.jl")
include("rewriters/sourcefiles.jl")
include("rewriters/modulereference.jl")
include("rewriters/executecode.jl")
include("rewriters/packagewatcher.jl")
include("rewriters/parsecode.jl")
include("rewriters/parseansi.jl")
include("rewriters/resolvereferences.jl")
include("rewriters/backlinks.jl")
include("rewriters/storkindex.jl")
include("rewriters/saveattributes.jl")
include("rewriters/docversions.jl")
include("rewriters/staticassets.jl")

export DocumentFolder, CheckLinks, SourceFiles, ModuleReference, ExecuteCode, ParseCode,
       ResolveReferences, Backlinks, StorkSearchIndex, SaveAttributes, DocVersions,
       StaticAssets, DocumentationFiles, ResolveSymbols

FRONTENDDIR = ""

function __init__()
    global FRONTENDDIR = @get_scratch!("frontend")
end

# Lastly, we have functionality to help with setting up and running complete documentation
# projects.

include("frontend.jl")
include("docs.jl")
include("pkgtemplate.jl")

export servedocs

end
