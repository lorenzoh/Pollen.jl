using Pollen
using Pkg

m = Pollen
ms = [
    m,
]


project = Project(
    Pollen.Rewriter[
        Pollen.DocumentFolder(pkgdir(m), prefix = "documents"),
        Pollen.ParseCode(),
        Pollen.ExecuteCode(),
        Pollen.PackageDocumentation(ms),
        Pollen.DocumentGraph(),
        Pollen.SearchIndex(),
        Pollen.SaveAttributes((:title,)),
        Pollen.LoadFrontendConfig(pkgdir(m))
    ],
)
