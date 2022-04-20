Refactorings:

- [ ] identify documents uniquely by strings, not `Path`s
- [ ] find and remove old files and definitions that are no longer used
- [ ] suffix Formats with Format, e.g. HTMLFormat so they can be exported without name conflicts
- [ ] use thread-safe dictionary data structure to make use of parallelism and speed up builds
- [ ] add InlineTest.jl

Fixes:

- get MIME types to work with frontend

Documentation:

- [ ] toc.json
- [ ] tutorial on `XTree`s

Features:

- make additional package PollenFrontend.jl that sets up npm project for you and lets preview documentation with one `serve` call.
- inline HTML when parsing Markdown
- use JuliaSyntax.jl for better 

Frontend:

- better syntax highlighting