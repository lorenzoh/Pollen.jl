# Working with documents

{.subtitle}
Learn how Pollen represents documents and how to load them from different file formats as well as transform them. 

At its core, Pollen is a package for creating and transforming documents. For example, this documentation is comprised of many different documents. This page, for example, is created from a Markdown file which you can find here: [`Pollen.jl/docs/tutorials/documents.md`](https://github.com/lorenzoh/Pollen.jl/blob/main/docs/tutorials/documents.md).

This tutorial will give you some insight into how Pollen documents are represented and how this representation makes many forms of common document processing steps possible.

## Documents as trees

If you have worked with HTML before, you'll know that it uses a tree-like data format to represent documents. For example, the following is an HTML snippet of a paragraph with some marked up text:

```html
<p class="subtitle">
    Hello world, this is some <strong>marked up</strong> text.
</p>
```

Pollen similarly represents documents as a tree. We can represent the above HTML as follows using Pollen:

{cell output=false}
```julia
using Pollen

Node(:p,
    "Hello world, this is some ",
    Node(:strong, "marked up"),
    " text.";
    class = "subtitle"
)
```

## Format-independent documents

HTML is a natural source for this kind of data, but Pollen can read or write documents from and to different formats, like Markdown files, Julia source files, Jupyter notebooks and JSON.

For example, we can parse Markdown text and render it back as HTML:

{cell}
```julia
doc = Pollen.parse("""
# Title

Some text with _markdown_ features.
""", MarkdownFormat())
```

{cell}
```julia
Pollen.render(doc, HTMLFormat())
```

Supporting many different formats allows us to work with different source documents and apply the same set of powerful transformations to documents. So, what can we actually do with our documents?

## Transforming documents

Pollen uses document transformations to implement many different features like executing code cells, syntax highlighting, finding hyperreferences and more.

To get a feel for this, let's implement the following transformation: given a document with `:code` tags, evaluate the code as a Julia expression and replace it with the resulting value. For example, let's say we have this document (parsed from Markdown for convenience):

{cell}
```julia
doc = Pollen.parse("What is 2 + 2? It is `2 + 2`", MarkdownFormat())
```

The result that we want is the same document, but the `"2 + 2"` replaced with the result of the calculation: 4.

{cell}
```julia
Node(:md, Node(:p, "What is 2 + 2? It is ", 4))
```

### Finding the code tags

To transform the code `"2 + 2"`, we first need to find it. For this, we'll use a [`Selector`](#). Selectors allow us to find specific nodes or leaves in a document tree. Here, we'll use [`SelectTag`](#) to find all nodes with a `:code` tag.

{cell}
```julia
node = selectfirst(doc, SelectTag(:code))
```

Next, we need to extract the string of code. Using [`AbstractTrees.children`](#), we can see that the node has 1 child, a [`Leaf`](#) with a string value.

{cell}
```julia
children(node)
```

We can get the leaf value with empty index notation (`[]`):

{cell}
```julia
codestr = only(children(node))[]
```

And we can execute the code:

{cell}
```julia
runcode(str) = Base.include_string(@__MODULE__, str)

runcode(codestr)
```

Now we know how to find nodes with code, how to get the code string, and how to run it. In the next step, we'll create a function that modifies a document, replacing code with its result.

### Transforming the tree

If our document was a list of nodes, we could find the relevant elements and `map` the code-running function over them. We can do something similar to a tree with a so-called catamorphism. At the risk of upsetting category theorists, I'll say that a catamorphism can be seen as _a `map` over trees_. Pollen implements it as the function [`cata`](#) which takes a function and a tree as arguments. The function is applied to all nodes and leaves, resulting in a new tree 🌳. For example, we can use it to modify the tags of all nodes:

{cell}
```julia
cata(doc) do subtree
    subtree isa Node ? withtag(subtree, :newtag) : subtree
end
```

`cata` can also take a [`Selector`](#) as a third argument. If specified, only the nodes matchign the selector will be modified. We'll use the above selector to map our code-running function over all nodes with a `:code` tag.

{cell}
```julia
function withcodeeval(doc)
    cata(doc, SelectTag(:code)) do node
        Leaf(runcode(only(children(node))[]))
    end
end

outdoc = withcodeeval(doc)
```

With this, we've implemented a reusable transformation that can be applied to other documents as well. Go ahead and try it with some other examples!

{cell}
```julia
outdoc2 = withcodeeval(
    Pollen.parse(
        "The **time** is `using Dates; Dates.now()`",
        MarkdownFormat()))
```

Finally, we can render the resulting document out to HTML. We wrap the HTML string in `Base.HTML` so that it's displayed as such here.

{cell}
```julia
Pollen.render(outdoc2, HTMLFormat()) |> HTML
```
