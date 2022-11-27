# How to preview documentation locally

To preview docs of a package that uses Pollen.jl for documentation, use [`servedocs`](#):

```julia
using Pollen, MyPackage
servedocs(MyPackage)
```

Once the pages are built, navigate to [localhost:5173](http://localhost:5173) to preview the documentation.

## Live reload

You can make changes to a file that is part of the documentation while the preview is running. For example, modify a Markdown file and Pollen.jl will reload it and rebuild just that page.

To update open pages in the preview, press **`Shift+R`**.

## Solving frontend issues

When running [`servedocs`], you might face the following issue:

```julia
[ Info: Starting server...
[ Info: Stopped frontend dev server
```

This is likely due to some issues on the frontend side, especially of the installation.

To verify do the following:

```julia
dir = Pollen.FRONTENDDIR
cd(dir)
run(`npm run install`)
```

Look if any error appears. If so, you probably need
[to upgrade your `npm` and `node` version](https://nodejs.org/en/).
Once the installation does not throw errors, try running

```julia
run(`npm run dev`)
servedocs(MyPackage; frontend=false)
```

and eventually report any errors appearing.
