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

