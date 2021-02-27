struct Files <: Format end


function parse(path::AbstractPath, ::Files)
    tree = FileTree(path)
    return xexpr(tree)
end

function xexpr(tree::FileTree)
    return xexpr(
        :folder,
        Dict(:path => FileTrees.path(tree), :name => tree.name),
        [xexpr(child) for child in (tree.children)])

end


xexpr(file::FileTrees.File) = xexpr(
    :file,
    Dict(:path => FileTrees.path(file), :name => file.name))


function render(dst::AbstractPath, xtree::XExpr, format::Files)
    if (isdir(dst) && !isempty(readdir(dst))) || isfile(dst)
        error("`dst` already exists, aborting.")
    end
    mkpath(dst)
    @assert all(getfield.(collect(select(xtree, SelectTag(:file))), :tag) .== :file)
    for folder in select(xtree, SelectTag(:folder))
        mkpath(joinpath(dst, folder.attributes[:path]))
    end

    for file in select(xtree, SelectTag(:file))
        content = only(file.children)
        path = joinpath(dst, withext(file.attributes[:path], "html"))
        format = extensionformat(Val(Symbol(extension(path))))
        format = HTML()
        render!(path, content, format)
    end
end


function withext(path::AbstractPath, ext)
    return joinpath(parent(path), "$(filename(path)).$ext")
end
