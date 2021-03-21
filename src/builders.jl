abstract type Builder end


"""
    build(project, builder[, docs])

Build every document named in `docs` using `builder`. `docs` defaults
to `keys(project.sources)`, meaning every document will be built. If you only
want to rebuild previously built files, use [`rebuild`](#).
"""
function build(project::Project, builder::Builder)
    # Build all documents
    dirtypaths = addfiles!(project, project.sources)

    # Save to disk
    build(builder, project, dirtypaths)

    return builder
end

"""
    build(project)

Build project to a temporary directory with [`HTML`](#) format.
"""
build(project) = build(project, FileBuilder(HTML(), Path(mktempdir())))


"""
    rebuild(project, builder)

Build previously built documents in projects using `builder`. Equivalent to
`build(project, builder, keys(project.outputs))`.
"""
rebuild(project, builder) = build(project, builder, keys(project.outputs))

"""
    struct FileBuilder <: Builder

Build every document to a file in `dir` using output `format`.
"""
struct FileBuilder <: Builder
    format::Format
    dir::AbstractPath
end


function build(builder::FileBuilder, project::Project, dirtypaths = keys(project.sources))
    # TODO: make threadable for performance
    for p in collect(dirtypaths)
        buildtofile(project.outputs[p], p, builder.dir, builder.format)
    end

    # TODO: make threadable for performance
    for rewriter in project.rewriters
        postbuild(rewriter, project, builder)
    end
end


function buildtofile(xtree, p, dir, format)
    fullpath = withext(joinpath(dir, p), formatextension(format))
    try
        mkpath(parent(fullpath))
    catch end
    render!(fullpath, xtree, format)
end
