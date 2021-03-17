

mutable struct HTMLTemplater <: Rewriter
    assets::Assets
    template::XNode
    templatepath::AbstractPath
    inlineincludes::Bool
    insertpos::Position
end

Base.show(io::IO, templater::HTMLTemplater) = print(io, "HTMLTemplater($(templater.assets)), $(templater.templatepath)")

function HTMLTemplater(
        templatepath::AbstractPath,
        includes::Vector{<:AbstractPath}=Path[];
        assetdir = Path("."),
        inlineincludes=false,
        insertpos=FirstChild(SelectTag(:body)),
    )
    template = Pollen.parse(templatepath)
    assets = Assets(Dict(joinpath(p"template/", p) => absolute(joinpath(assetdir, p)) for p in includes))
    if inlineincludes
        template = inlineintemplate(template, collect(values(assets.assets)))
    else
        template = includeintemplate(template, collect(keys(assets.assets)))
    end

    return HTMLTemplater(assets, template, templatepath, inlineincludes, insertpos)
end


function updatefile(templater::HTMLTemplater, p, doc)
    # Include the document in the template
    doc = insertfirst(templater.template, doc, templater.insertpos)
    return doc
end


function includeintemplate(template::XNode, includes)
    for p in includes
        ext = extension(p)
        if ext == "css"
            x = XNode(:link, Dict(:rel => "stylesheet", :href => "/" * string(p)))
        elseif ext == "js"
            x = XNode(:script, Dict(:src => "/" * string(p)))
        else
            continue
        end
        template = insertfirst(template, x, FirstChild(SelectTag(:head)))
    end

    return template
end


function inlineintemplate(template::XNode, includes)
    for p in includes
        ext = extension(p)
        if ext == "css"
            x = XNode(:style, [XLeaf(read(p, String))])
        elseif ext == "js"
            x = XNode(:script, [XLeaf(read(p, String))])
        end
        template = insertfirst(template, x, FirstChild(SelectTag(:head)))
    end
    return template
end


function getfilehandlers(templater::HTMLTemplater, project, dir, builder)
    handlers =  [
        # When template changes, reload it and rebuild every file
        (
            absolute(templater.templatepath),
            () -> onupdatetemplate(templater, project, builder)
        ),
    ]

    if templater.inlineincludes
        handlers = vcat(handlers, [
            (p, () -> onupdatetemplate(templater, project, builder)) for p in values(templater.assets.assets)
        ])
    else
        handlers = vcat(handlers, getfilehandlers(templater.assets, project, dir, builder))
    end
    return handlers
end


function onupdatetemplate(templater, project, builder)
    template = Pollen.parse(templater.templatepath)
    if templater.inlineincludes
        templater.template = inlineintemplate(template, collect(values(templater.assets.assets)))
    else
        templater.template = includeintemplate(template, collect(keys(templater.assets.assets)))
    end
    build(builder, project)
end


function postbuild(templater::HTMLTemplater, project, builder)
    postbuild(templater.assets, project, builder)
end


reset!(templater::HTMLTemplater) = reset!(templater.assets)
