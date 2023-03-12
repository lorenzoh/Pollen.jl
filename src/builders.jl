abstract type Builder end

"""
    build(project, builder[, docs])

Build every document named in `docs` using `builder`. `docs` defaults
to `keys(project.sources)`, meaning every document will be built. If you only
want to rebuild previously built files, use [`rebuild`](#).
"""
function build(project::Project, builder::Builder)
    return project

    # Build all documents
    dirtypaths = addfiles!(project, project.sources)

    # Save to disk
    build(builder, project, dirtypaths)

    return builder
end

"""
    build(project)

Build project to a temporary directory with [`HTMLFormat`](#) format.
"""
build(project) = build(project, FileBuilder(HTMLFormat(), Path(mktempdir())))

function fullbuild(project, builder)
    paths = rewritesources!(project)
    build(builder, project, paths)
end

"""
    rebuild(project, builder)

Build previously built documents in projects using `builder`. Equivalent to
`build(project, builder, keys(project.outputs))`.
"""
rebuild(project, builder) = build(project, builder, keys(project.outputs))

"""
    FileBuilder(format, dir) <: Builder

Build every document to a file in `dir` using output `format`.
"""
struct FileBuilder <: Builder
    format::Format
    dir::AbstractPath
end
FileBuilder(format::Format, p::String) = FileBuilder(format, Path(p))

function build(builder::FileBuilder, project::Project,
               dirtydocids = keys(project.outputs))
    # TODO: make threadable for performance. issue is paths not being created
    dirtydocids = collect(dirtydocids)
    progress = _default_progress(length(dirtydocids), desc = "Rendering...")
    foreach(enumerate(dirtydocids)) do (i, docid)
        buildtofile(project.outputs[docid], docid, builder.dir, builder.format)
        showvalues = i == length(dirtydocids) ? [] : [(Symbol("Document"), dirtydocids[i+1])]
        ProgressMeter.next!(progress; showvalues)
    end

    for rewriter in project.rewriters
        postbuild(rewriter, project, builder)
    end
end

function buildpath(dir, docid, format)
    ext = formatextension(format)
    docext = splitext(docid)[2][2:end]
    path = joinpath(dir, docid)
    if ext != docext
        path *= ".$ext"
    end
    Path(path)
end

function buildtofile(xtree, docid::String, dir, format)
    fullpath = buildpath(dir, docid, format)
    try
        mkpath(parent(fullpath))
    catch
    end
    render!(fullpath, xtree, format)
end
