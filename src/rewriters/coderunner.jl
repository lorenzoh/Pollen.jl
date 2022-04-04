# # Code execution
#
# For documentation sites and blog articles, including code snippets
# in your documents is a great way to connect the theoretical concepts
# with the application. Here we implement [`ExecuteCode`](#), a [`Rewriter`](#)
# that executes marked code blocks and includes the output in the document.
#
# You can use the rewriter by passing it to the [`Project`](#) constructor:
# ```julia
# project = Project(dir, [ExecuteCode()])
# ```
#
# Executing code blocks takes a lot of time, so to give a pleasant interactive
# document creation experience we should make code execution incremental. If a document
# changes, we'll only rerun the code blocks that changed and the ones following them
# (since they may depend on the state of the previous blocks).
#
# Another consideration is that groups of code blocks should be isolated so that they
# don't affect the execution of other groups. We'll assume by default that all code
# blocks marked executable in one document are a group but give the ability to specify
# a different group where needed.
#
#
# ## Cached code execution
#
# Let's focus on the cached code execution before integrating it into the document
# processing system.
#
# We'll implement [`runblockscached`](#), a function that runs a collection of code blocks
# inside a scope and captures the printed output as well as the result of the last code
# line. It caches the results so that only blocks that change have to be rerun.
#
# The cache holds the code, outputs and results for a group of code blocks, as well as
# a module that the code is evaluated in.

mutable struct RunCache
    blocks::Vector{String}
    outputs::Vector{Any}
    results::Vector{Any}
    module_::Module
end

RunCache() = RunCache(String[], [], [], Module())
RunCache(s::Symbol) = RunCache(String[], [], [], Module(s))
Base.show(io::IO, cache::RunCache) = print(io, "RunCache($(nameof(cache.module_)))")

# In case we don't have the result of a block cached, we capture output and result with
# [`runblock`](#).

function runblock(m::Module, codeblock)
    c = IOCapture.capture(rethrow=InterruptException) do
        Base.include_string(m, codeblock)
    end
    return c.output, c.value
end

# We put these two together for [`runblockscached`](#):

function runblockscached(cache::RunCache, blocks)
    outputs = []
    results = []
    updated = false
    for (i, block) in enumerate(blocks)
        oldblock = length(cache.blocks) >= i ? cache.blocks[i] : nothing
        if !updated && oldblock == block
            output, result = cache.outputs[i], cache.results[i]
        else
            output, result = runblock(cache.module_, block)
            updated = true
        end
        push!(outputs, output)
        push!(results, result)
    end
    return RunCache(blocks, outputs, results, cache.module_)
end


## Rewriter
#
# The rewriter for code execution finds code blocks matching a selector,
# groups them, executes them and includes the output and result in a document.
# We also want to warn when an error is thrown which is useful when changes in
# source code break examples.

# The default selector mimicks the behavior of Publish.jl. "pre[lang="julia" cell]
const PUBLISH_CODEBLOCK_SELECTOR = SelectTag(:pre) & SelectAttrEq(:lang, "julia") & SelectHasAttr(:cell)

Base.@kwdef struct ExecuteCode <: Rewriter
    # Execution caches for each group of code blocks
    caches::Dict{Symbol, RunCache} = Dict{Symbol, RunCache}()
    # Whether to log when a code block throws an error
    warnonerror::Bool = true
    # Selector for code blocks to execute
    codeblocksel::Selector = PUBLISH_CODEBLOCK_SELECTOR
    # Function to get a group from a selected block
    groupfn = x -> get(attributes(x), :cell, "main")
    # Lock to avoid crashes
    lock::ReentrantLock = ReentrantLock()
end

# The rewriter acts on the document tree with [´rewritedoc`](#).

function rewritedoc(executecode::ExecuteCode, p, doc)
    blocks = collect(select(doc, executecode.codeblocksel))
    codes = gettext.(blocks)

    groupids = [creategroupid(p, executecode.groupfn(block)) for block in blocks]
    outputs, results = lock(executecode.lock) do
        executegrouped!(executecode.caches, codes, groupids)
    end

    if executecode.warnonerror
        for (i, result) in enumerate(results)
            if result isa LoadError
                @warn "Got evaluation error in code block:\n\n$(codes[i])\n" error=result.error doc=p block=i line=result.line
            end
        end
    end

    newblocks = [
        Node(
            :div,
            merge(attributes(block), Dict(:class => "cellcontainer")),
            XTree[
                withattributes(block, merge(attributes(block), Dict(:class => "codecell"))),
                get(attributes(block), :output, "true") == "true" ? viewcodeoutput(outputs[i]) : Leaf(""),
                get(attributes(block), :result, "true") == "true" ? viewcoderesult(results[i]) : Leaf(""),

            ],
        )
        for (i, block) in enumerate(blocks)
    ]

    return replacemany(doc, newblocks, executecode.codeblocksel)
end

# We use a helper for executing the code blocks in groups and restoring the ordering
# afterwards:

function executegrouped!(caches, codes, groupids)
    is = []
    codesgrouped = Dict{Symbol, Vector{String}}()

    for (i, (gid, code)) in enumerate(zip(groupids, codes))
        groupcodes = get!(codesgrouped, gid, String[])
        push!(groupcodes, code)
        push!(is, (gid, length(groupcodes)))
    end

    for gid in keys(codesgrouped)
        cache = get!(caches, gid, RunCache(gid))
        caches[gid] = runblockscached(cache, codes)
    end

    outputs = [caches[gid].outputs[i] for (gid, i) in is]
    results = [caches[gid].results[i] for (gid, i) in is]

    return outputs, results
end

creategroupid(path, groupname) = Symbol("$(CommonMark.slugify(string(path)))_$groupname")

# The code output and result are tagged with classes "codeoutput" and
# "coderesult" in the output document.


function viewcodeoutput(output::AbstractString)
    if isempty(output)
        return Leaf("")
    else
        return Node(
            :pre,
            Dict(:class => "codeoutput"),
            [Node(:code, [Leaf(output)])])
    end
end


function viewcoderesult(result::AbstractString)
    return Node(
        :pre,
        Dict(:class => "coderesult"),
        [Node(:code, [Leaf(result)])],
    )
end


viewcoderesult(result::Nothing) = Leaf("")


function viewcoderesult(result)
    if any([showable(m, result) for m in HTML_MIMES[1:end-1]])
        return Node(
            :div,
            Dict(:class => "coderesult"),
            [Leaf(result)],
        )
    else
        return Node(
            :pre,
            Dict(:class => "coderesult"),
            [Node(:code, [Leaf(result)])],
        )
    end
end


# Resetting the rewriter clears the caches:

function reset!(executecode::ExecuteCode)
    foreach(k -> delete!(executecode.caches, k), keys(executecode.caches))
    return
end
