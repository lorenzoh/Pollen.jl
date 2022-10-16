# How to set up package documentation

{.subtitle}
How-to for setting up Pollen.jl documentation for packages. See [the tutorial](/docs/tutorials/setup.md) for a more in-depth look.

Pollen.jl comes with a [PkgTemplates.jl](https://github.com/invenia/PkgTemplates.jl) template that performs necessary setup steps to add Pollen documentation to a new package you're creating. To use it, add [`Pollen.PollenPlugin`](#) to the list of plugins when constructing a package template, and call it to create a package:


```julia
using Pollen, PkgTemplates

template = Template(plugins=[
        Pollen.PollenPlugin(),
        PkgTemplates.Tests(project=true),
        PkgTemplates.Git(ssh=true),
        GitHubActions(),
    ], user="username")

template("PackageName")
```

## Setting up Pollen.jl documentation for an existing package

If you want to add Pollen documentation to an existing package, make sure to remove any Documenter.jl-specific files, e.g. by renaming the existing "docs/" folder.

You can then call the plugin manually:

```julia
using Pollen, PkgTemplates


function setuppollen(pkgdir)
    plugin = Pollen.PollenPlugin()
    t = Template(plugins=[plugin], user="mock")
    PkgTemplates.validate(plugin, t)
    PkgTemplates.prehook(plugin, t, pkgdir)
    PkgTemplates.hook(plugin, t, pkgdir)
    PkgTemplates.posthook(plugin, t, pkgdir)
end

```