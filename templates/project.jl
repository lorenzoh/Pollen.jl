using Pollen
using Pkg

# The main package you are documenting
using <<PKG>>
m = <<PKG>>


# Packages that will be indexed in the documentation. Add additional modules
# to the list.
ms = [m]


# Add rewriters here
project = Project(
    Pollen.Rewriter[
        DocumentFolder(Pkg.pkgdir(m), prefix = "documents"),
        ParseCode(),
        ExecuteCode(),
        PackageDocumentation(ms),
        StaticResources(),
        Backlinks(),
        SearchIndex(),
        SaveAttributes((:title,)),
        LoadFrontendConfig(Pkg.pkgdir(m))
    ],
)
