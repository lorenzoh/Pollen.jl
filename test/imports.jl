using Pollen
using Pollen: changehrefextension, referencetype, Reference, FileBuilder
using Pollen: XTree, Node, tag, attributes, children, Leaf, cata, catafold, foldleaves
using Pollen: matches, Selector, SelectOr, SelectAnd, SelectNode, SelectLeaf,
    SelectNot, SelectAttrEq, SelectHasAttr, SelectTag
using Pollen: catafirst, replace, replacefirst, insert, insertfirst, NthChild, After, Before
using Pollen: Markdown, HTML, createsources!, geteventsource, Server, ServeFiles, ServeFilesLazy
using Test
using TestSetExtensions
using FilePathsBase

using Pollen: addsource!, addrewrite!, addbuild!, applyupdates!, FileServer, createsources!
using Pollen: start, stop

function testproject()
    dir = Path(mktempdir())
    write(joinpath(dir, "hi.md"), "Hello")
    proj = Project([DocumentFolder(dir)])
    return proj
end

function testbuilder()
    dir = Path(mktempdir())
    return FileBuilder(HTML(), dir)
end


testserver() = Server(testproject(), testbuilder())
