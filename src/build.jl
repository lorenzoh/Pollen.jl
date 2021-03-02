
function rendertemplate(template; kwargs...)
    for (tag, x) in kwargs
        template = Pollen.replacefirst(template, x, SelectTag(tag))
    end
    return template
end

SELHEADINGS = SelectOr(SelectTag.((:h2, :h3, :h4)))
CONTENT_RULES = [
        (ChangeTag(:article), SelectTag(:body)),
        (AddSlugID(), SELHEADINGS),
        (AddTableOfContents((:h2, :h3, :h4), SelectTag(:h1)), SelectTag(:article)),
    ]
HTML_RULES = [
    (htmlify, SelectTag(:toc)),
]
RULES = vcat(CONTENT_RULES, HTML_RULES)

HTMLTEMPLATE = Pollen.parse(Path(joinpath(@__DIR__, "../static/basic.html")))
STYLESHEET = Pollen.parse(Path(joinpath(@__DIR__, "../static/pollen.css")))
TEMPLATE = rendertemplate(HTMLTEMPLATE, style = STYLESHEET)


function build(
        srcdir::AbstractPath,
        dstdir::AbstractPath = Path(mktempdir());
        format = Pollen.HTML(),
        template = TEMPLATE)
    tree = Pollen.parsefiletree(srcdir)
    tree = FileTrees.mapvalues(tree) do doc
        transformdoc(doc, RULES, template)
    end
    savefiletree(tree, dstdir, format)
    return dstdir
end


function transformdoc(doc::XExpr, rules, template)
    # output-agnostic transformations
    doc = Pollen.rewrite(doc, rules)


    # HTML-specific
    return rendertemplate(template, article = doc)
end
