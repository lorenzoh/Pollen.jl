


mutable struct Project
    srctree::FileTree
    outtree::FileTree
    rewriters::Vector{<:Rewriter}
    format::Format
    dst::AbstractPath
end

function Project(srcdir::AbstractPath, dstdir::AbstractPath, rewriters, format = HTML())
    tree = parsefiletree(srcdir)
    Project(tree, tree, rewriters, format, dstdir)
end


"""
    addfiles(tree, rewriters, files) -> dirtypaths

Updates `files`  (pairs of paths and x-expressions) on `tree`
using `rewriters`.
May produce more files and call itself recursively.
"""
function addfiles(
        srctree,
        outtree,
        rewriters,
        files; dirtypaths = Set())

    isempty(files) && return srctree, outtree, dirtypaths

    # Update source tree
    newsrcdocs = Dict()
    for (p, doc) in files
        srctree = hasfile(srctree, p) ? srctree : touch(srctree, p)
        newsrcdocs[p] = doc
    end
    srctree = setvalues(srctree, newsrcdocs)

    # Process new/changed files on document-level
    newoutdocs = Dict()
    for (p, _) in files
        doc = srctree[p][]
        outtree = hasfile(outtree, p) ? outtree : touch(outtree, p)
        for rewriter in rewriters
            doc = updatefile(rewriter, p, doc)
        end
        newoutdocs[p] = doc
        push!(dirtypaths, p)
    end
    outtree = setvalues(outtree, newoutdocs)

    # Apply project-level changes like updating tree elements,
    # and creating new files.
    newfiles = Set()
    for rewriter in rewriters
        outtree, newfs, dirtyps = updatetree(rewriter, outtree)
        dirtypaths = dirtypaths ∪ dirtyps
        newfiles = newfiles ∪ newfs
    end

    return addfiles(srctree, outtree, rewriters, newfiles; dirtypaths = dirtypaths)
end


function setvalues(tree::FileTree, valuesdict)
    return map(tree) do f
        val = get(valuesdict, relative(path(f), path(tree)), f[])
        return setvalue(f, val)
    end
end


function addfiles!(project::Project, files)
    project.srctree, project.outtree, dirtypaths = addfiles(project.srctree, project.outtree, project.rewriters, files)
    return dirtypaths
end


function build(project::Project)
    fs = [(relative(path(f), path(project.srctree)), f[]) for f in files(project.srctree)]
    dirtypaths = addfiles!(project, fs)
    rebuild(project, dirtypaths)
end


function rebuild(project, dirtypaths)
    pt = path(project.outtree)
    dirtytree = filter(project.outtree) do f
        p = path(f)
        return isdir(p) || relative(p, path(project.outtree)) in dirtypaths
    end
    savefiletree(dirtytree, project.dst, project.format)
end


function buildfile(project, p)
    doc = project.tree[p][]
    p = withext(joinpath(project.dst, p), formatextension(project.format))
    render!(p, doc, project.format)
end

function relativepaths(tree::FileTree)
    return (relative(path(file), path(tree)) for f in files(tree))
end
