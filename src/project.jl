

function findfiles(dir::AbstractPath; exts = ("md", "ipynb"), includehidden = false)
    it = filter(collect((relative(p, dir) for p in walkpath(dir)))) do p
        (extension(p) in exts) && (includehidden || !startswith(filename(p), '.'))
    end
    return it

end


mutable struct Project
    sources::Dict{AbstractPath, XTree}
    outputs::Dict{AbstractPath, XTree}
    rewriters::Vector{<:Rewriter}
end

Project(dir::AbstractPath, rewriters::Vector{<:Rewriter}) =
    Project(dir, collect(findfiles(dir)), rewriters)

Project(paths::Vector{<:AbstractPath}, rewriters::Vector{<:Rewriter}) =
    Project(Path(pwd()), paths, rewriters)

function Project(dir::AbstractPath, paths::Vector{<:AbstractPath}, rewriters::Vector{<:Rewriter})
    sources = Dict{AbstractPath, XTree}()
    Threads.@threads for p in paths
        sources[p] = parse(joinpath(dir, p))
    end
    targets = Dict{AbstractPath, XTree}()
    return Project(sources, targets, rewriters)
end


Base.show(io::IO, project::Project) = print(io, "Project($(length(project.sources)) documents, $(typeof.(project.rewriters))")


function addfiles(
        sources::Dict,
        outputs::Dict,
        rewriters,
        newsources;
        dirtypaths = Set())
    sources = copy(sources)
    outputs = copy(outputs)
    dirtypaths = addfiles!(sources, outputs, rewriters, newsources; dirtypaths = dirtypaths)
    return sources, outputs, dirtypaths
end


"""
    addfiles(sources, outputs, rewriters, newsources) -> (sources', outputs', dirtypaths)
    addfiles!(sources, outputs, rewriters, newsources) -> dirtypaths

Updates `sources` and `outputs` based on new or updated `changedsources`
using `rewriters`.
"""
function addfiles!(
        sources::Dict,
        outputs::Dict,
        rewriters,
        newsources::Dict;
        dirtypaths = Set())
    isempty(newsources) && return dirtypaths

    # Process new/changed files on document-level
    for (p, xtree) in newsources
        sources[p] = xtree
        for rewriter in rewriters
            xtree = updatefile(rewriter, p, xtree)
        end
        outputs[p] = xtree
        push!(dirtypaths, p)
    end

    # Apply project-level changes like updating tree elements,
    # and creating new files.
    newersources = Dict{AbstractPath, XNode}()
    for rewriter in rewriters
        outputs, new, dirtyps = updatetree(rewriter, outputs)
        dirtypaths = dirtypaths ∪ dirtyps
        newersources = merge(newersources, new)
    end

    return addfiles!(sources, outputs, rewriters, newersources; dirtypaths = dirtypaths)
end


function addfiles!(project::Project, newsources)
    dirtypaths = addfiles!(project.sources, project.outputs, project.rewriters, newsources)
    return dirtypaths
end


function build(project::Project, dst::AbstractPath, format::Format)
    # Build all documents
    dirtypaths = addfiles!(project, project.sources)

    # Save to disk
    rebuild(project, dst, format, dirtypaths)
end


function rebuild(project, dst, format, dirtypaths)
    # Save all dirty documents to disk
    for p in collect(dirtypaths)
        buildfile(project, p, dst, format)
    end

    # Perform post-build actions
    # TODO: make thread-safe and use `@threads`
    for rewriter in project.rewriters
        postbuild(rewriter, project, dst, format)
    end
end


function buildfile(project, p, dst, format)
    dst = joinpath(dst, p)
    fullpath = withext(dst, formatextension(format))
    dir = parent(fullpath)
    try
        mkpath(parent(fullpath))
    catch
    end
    render!(fullpath, project.outputs[p], format)
end
