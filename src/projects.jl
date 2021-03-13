

function documentationproject(m::Module)
    dir = Path(pkgdir(m))
    doctree = Pollen.loaddoctree(joinpath(dir, "toc.md"))

    rewriters = [
        Replacer(x -> Pollen.withtag(x, :article), SelectTag(:body)),
        AddID(SEL_H1234),
        ExecuteCode(),
        Referencer([m]),
        HTMLTemplater(
            p"Pollen/static/hugobook.html",
            [p"Pollen/static/hugobook.css"],
            inlineincludes = true,
            insertpos = NthChild(2, SelectAttrEq(:class, "book-page"))
        ),
        Inserter([
            (Pollen.toccreator(hierarchysels = SelectTag.((:h1, :h2, :h3, :h4))), FirstChild(SelectAttrEq(:id, "toc"))),
            ((p, x) -> doctree, FirstChild(SelectAttrEq(:id, "sidebar"))),
            ((p, x) -> XLeaf(string(m)), FirstChild(SelectAttrEq(:id, "title"))),
        ]),
        ChangeLinkExtension("html"),
        HTMLify(),
    ]

    project = Project(dir, rewriters)
end


function serve(m::Module)
    project = documentationproject(m)
    serve(project, Path(pkgdir(m)))
end
