using Pollen, ModuleInfo, Pkg

# The main package you are documenting
using Pollen
m = Pollen


# Packages that will be indexed in the documentation. Add additional modules
# to the list.
ms = [m]

function createpackageindex(; package = m, modules = ms, tag = "dev")
    pkgtags = Dict(string(package) => tag)
    return PackageIndex(modules; recurse = 0, pkgtags, cache = true, verbose = true)
end


function createproject(; tag = "dev", package = m, modules = ms)
    pkgindex = createpackageindex(; tag, package, modules)
    pkgtags = Dict(string(package) => tag)
    packages = [
        ModuleInfo.getid(pkgindex.packages[1]),
        [d for d in pkgindex.packages[1].dependencies
        if d in [ModuleInfo.getid(p) for p in pkgindex.packages]]...]

    project = Project([
        # Add written documentation, source files, and symbol docstrings as pages
        DocumentationFiles([package]; pkgtags),
        SourceFiles(modules; pkgtags),
        ModuleReference(pkgindex),

        # Parse and run code
        ParseCode(),
        ExecuteCode(),

        # Resolve all links
        ResolveReferences(pkgindex),
        ResolveSymbols(pkgindex),
        Backlinks(),
        CheckLinks(),

        # Provide data for the frontend
        StorkSearchIndex(; tag, filterfn = startswith(string(package))),
        SaveAttributes((:title, :backlinks => []), useoutputs = true),
        DocVersions(package; tag = tag, dependencies = packages),
        StaticAssets(),
    ])


end
