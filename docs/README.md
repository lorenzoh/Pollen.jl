# Pollen.jl

A document generation system based on tree rewriting, built for interactive work.

Pollen.jl generates documentation for Julia packages that comes with many features:

- support for many input and output [format](/ref/Pollen.Format)s: [Markdown](/ref/Pollen.MarkdownFormat), [Jupyter notebooks](/ref/Pollen.JupyterFormat), [HTML](/ref/Pollen.HTMLFormat), [JSON](/ref/Pollen.JSONFormat), and [Julia source code](/ref/Pollen.JuliaSyntaxFormat)
- a modern frontend with Sliding Panes
- automatic hyperreferencing of code variables for discoverability
- source code browser
- code execution to ensure your code examples stay up-to-date
- automated builds, deployments and PR previews with GitHub Actions and GitHub Pages
- local preview with incremental builds for an improved developer experience

First, find out [how to install Pollen](howto/install.md) and then [how to setup package documentation](tutorials/setup.md).
