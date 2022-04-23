# How to install Pollen.jl

Pollen.jl is a package for the Julia programming language and can be installed like other packages using the built-in package managero

!!! note "In development"

    Since Pollen.jl is not yet released and has some unreleased package dependencies, you'll have to install these directly from their repositories for now as shown below.

Run the following in a Julia session to install Pollen and its dependencies:

```julia
using Pkg

Pkg.add([
    Pkg.PackageSpec(url="https://github.com/c42f/JuliaSyntax.jl"),
    Pkg.PackageSpec(url="https://github.com/lorenzoh/ModuleInfo.jl"),
    Pkg.PackageSpec(url="https://github.com/lorenzoh/Pollen.jl", rev="main"),
])
```