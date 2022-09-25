using Pollen
using Pkg

# The main package you are documenting
using <<PKG>>
m = <<PKG>>


# Packages that will be indexed in the documentation. Add additional modules
# to the list.
ms = [m]

function createpackageindex(; tag = "dev")
    pkgtags = Dict("<<PKG>>" => tag)
    return PackageIndex(ms; recurse = 1, pkgtags, cache = true, verbose = true)
end


function createproject(; tag = "dev")
    pkgtags = Dict("<<PKG>>" => tag)
    pkgindex = createpackageindex(; tag)
    packages = [ModuleInfo.getid(pkgindex.packages[1]), pkgindex.packages[1].dependencies...]

    project = Project([
        # Add written documentation, source files, and symbol docstrings as pages
        DocumentationFiles([Pollen]; pkgtags),
        SourceFiles(ms; pkgtags),
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
        StorkSearchIndex(; tag, filterfn = id -> startswith(id, "Pollen")),
        SaveAttributes((:title, :backlinks => []), useoutputs = true),
        DocVersions(Pollen; tag = tag, dependencies = packages),
    ])


end
