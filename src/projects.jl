

function documentationproject(
        m::Module;
        inlineincludes = false,
        executecode = true,
        refmodules = (m,),
        watchpackage = true,
    )
    dir = Path(pkgdir(m))
    doctree = Pollen.loaddoctree(joinpath(dir, "toc.md"))

    rewriters = Rewriter[]

    watchpackage && push!(rewriters, PackageWatcher([m]))

    push!(rewriters, DocumentFolder(dir))

    # Change each document :body into an :article
    push!(rewriters, Replacer(x -> Pollen.withtag(x, :article), SelectTag(:body)))

    # Add slugified IDs to all :h1, :h2, :h3, and :h4 tags
    push!(rewriters, AddID(SEL_H1234))

    # Run cells marked with "cell" attributes and include results in doc, as in Publish.jl
    executecode && push!(rewriters, ExecuteCode())

    # Find references to defined symbols in package and create reference pages for them
    push!(rewriters, Referencer(refmodules))

    # Insert each doc into a HTML template, and either link to CSS and JS or inline them
    push!(rewriters,
        HTMLTemplater(
            joinpath(ASSETDIR, "hugobook.html"),
            [p"hugobook.css"];
            assetdir = ASSETDIR,
            inlineincludes = inlineincludes,
            insertpos = NthChild(2, SelectAttrEq(:class, "book-page"))
        ))
    # Insert table of contents, a sidebar with document tree, and project title into
    # the template
    push!(rewriters, Inserter([
        (Pollen.toccreator(hierarchysels = SelectTag.((:h1, :h2, :h3, :h4))), FirstChild(SelectAttrEq(:id, "toc"))),
        ((p, x) -> doctree, FirstChild(SelectAttrEq(:id, "sidebar"))),
        ((p, x) -> XLeaf("$m.jl"), FirstChild(SelectAttrEq(:id, "title"))),
        (createtitle, FirstChild(SelectTag(:head))),
    ]))

    # Add "html" extensions to all links, e.g. ".md" -> ".md.html"
    push!(rewriters, ChangeLinkExtension("html"))

    # Replace absolute links by relative ones so that they are properly resolved, even
    # if output files are served under a subresource like "/Package.jl/dev/..."
    push!(rewriters, RelativeLinks())

    # Change non-html tags like :toc to a :div[class="toc"]
    push!(rewriters, HTMLify())

    # Include fonts
    push!(rewriters, Assets(joinpath(ASSETDIR, p"fonts"), dstdir = p"fonts/"))

    push!(rewriters, HTMLRedirect(p"README.md"))


    project = Project(rewriters)
end


function serve(m::Module; kwargs...)
    project = documentationproject(m)
    serve(project; kwargs...)
end


"""
    serve(project)
    serve(module)
"""
function serve(project::Project; lazy = true)
    builder = FileBuilder(HTML(), Path(mktempdir()))
    server = Server(project, builder)
    mode = lazy ? ServeFilesLazy() : ServeFiles()
    runserver(server, mode)
end


const ASSETDIR = joinpath(Path(pkgdir(Pollen)), p"static")
