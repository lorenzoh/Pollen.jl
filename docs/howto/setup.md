# How to set up package documentation

{.subtitle}
How-to for setting up Pollen.jl documentation for packages. See [the tutorial](/docs/tutorials/setup.md) for a more in-depth look.

Setting up Pollen.jl documentation consists of the following steps:

- Create boilerplate files
- Create a Julia project with documentation dependencies
- (Optional) Set up GitHub Actions and helper branches on the repository for automatic publishing

The steps apply to both **existing and newly created packages**.

## The tl;dr

To set up documentation for a package `MyPackage`, run:

```julia
using Pollen, MyPackage
dir = pkgdir(MyPackage)
config = Pollen.PollenPlugin()
Pollen.setup_docs_project(dir, config)
Pollen.setup_docs_files(dir, config)
Pollen.setup_docs_actions(dir, config)
```

Then, **commit all generated files** to make sure you have a clean Git working directory, and run:

```julia
Pollen.setup_docs_branches(dir, config)
```

You can then [preview the documentation locally](./preview.md).

## Longer version

### Step 1: Configuration

All setup steps use a configuration object:

{cell, resultshow=false}
```julia
using Pollen
config = Pollen.PollenPlugin()
```

Next, we need to set the folder where the package is stored:

```julia
dir = "~/.julia/dev/MyPackage"
# Alternatively
using MyPackage
dir = pkgdir(MyPackage)
```

!!! note "For older repositories"

    When adding documentation to an existing package, there is one option you may need to change: the name of the primary branch. If your repository's primary branch is `master` and not `main`, pass it in when creating the configuration:

    ```julia
    config = Pollen.PollenPlugin(branch_primary="master")
    ```

### Step 2: Set up files

To handle documentation-specific package dependencies, we set up a Julia project in the `"$dir/docs"` folder:

```julia
Pollen.setup_docs_project(dir, config)
```

Then, we set up file that configure how the documentation behaves:

```julia
Pollen.setup_docs_files(dir, config)
```

We also add Github Actions workflows so that the documentation can be built and deployed automatically:

```julia
Pollen.setup_docs_actions(dir, config)
```

### Step 3: Create helper branches for deployment

So that the documentation can be built and deployed on GitHub Pages, we need to set up two branches.

Before we do this, you must clean your git working directory, for example by committing the files generated above in the terminal:

```sh
$ git add .
$ git commit -m "Setup Pollen.jl files" 
```

After that, run:

```julia
Pollen.setup_docs_branches(dir, config)
```

---

That's it! Next, [preview the docs locally](./preview.md) to make sure everything works.
