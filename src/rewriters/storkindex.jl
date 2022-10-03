

Base.@kwdef struct StorkSearchIndex <: Rewriter
    filterfn = Returns(True)
    tag::String = "dev"
    stork_bin::String = get_stork_binary()
    corpus::Dict{String, Any} = Dict{String, Any}()
end


function build_corpus(documents; filterfn = Returns(true))
    corpus = Dict{String, Dict}()
    for (id, doc) in documents
        filterfn(id) || continue
        text = extract_text(doc)
        isempty(text) && continue
        corpus[id] = Dict("title" => attributes(doc)[:title], "contents" => text,
                          "url" => id)
    end
    return corpus
end

function rewriteoutputs!(outputs, stork::StorkSearchIndex)
    newcorpus = build_corpus(outputs, filterfn =stork.filterfn)
    merge!(stork.corpus, newcorpus)
    return outputs
end

function postbuild(stork::StorkSearchIndex, project, builder::FileBuilder)
    # create a config.toml and place it in the build directory

    config = Dict(
        "input" => Dict(
            "base_directory" => ".",
            "url_prefix" => "",
            "files" => collect(values(stork.corpus))
        )
    )
    mktemp()
    searchdir = mkpath(joinpath(builder.dir, "storksearch", stork.tag))
    configfile, indexfile = joinpath(searchdir, "config.toml"), joinpath(searchdir, "index.st")
    open(joinpath(searchdir, "config.toml"), "w") do f
        TOML.print(f, config)
    end
    build_stork_index(stork.stork_bin, string(configfile), string(indexfile))
end

function build_stork_index(stork_bin::String, config_file::String, output_file::String)
    run(`$stork_bin build -i $config_file -o $output_file`)
end



const LINEBREAKTAGS = [:h1, :h2, :h3, :h4, :p, :admonition, :blockquote, :mathblock, :table,
                 :hr, :li, :ul, :md, :admonitiontitle, :admonitionbody]

extract_text(node::Node) = extract_text!("", node, Val(Pollen.tag(node)))

function extract_text!(s, node::Node, ::Val)
    for ch in children(node)
        if ch isa Leaf
            ch isa Leaf{String} || continue
            s *= ch[]
        else
            s = extract_text!(s, ch, Val(Pollen.tag(ch)))
        end
    end

    if Pollen.tag(node) in LINEBREAKTAGS
        s *= "\n"
    end
    return s
end

function extract_text!(s, node::Node, ::Val{:julia})
    # TODO: find :md blocks inside source files and parse them
    for node in select(node, SelectTag(:Identifier) & SelectTag(:md))
        if tag(node) == :md
            extract_text!(s, node, Val(:md))
        else
            if (length(children(node)) == 1) && (only(children(node)) isa Leaf{String})
                s *= only(children(node))[]
                s *= " "
            end
        end
    end
    s *= "\n"
    return s
end


function get_stork_binary()
    dir = @get_scratch!("stork")
    file = joinpath(dir, "stork")
    if isfile(file)
        return file
    end
    url = if Sys.islinux()
        @info """Downloading stork executable for Ubuntu 20.04. If you're using a different
        Linux distribution, it may fail."""
        "https://files.stork-search.net/releases/v1.5.0/stork-ubuntu-20-04"
    elseif Sys.isapple()
        @info """Downloading stork executable for Intel-based Macs. If you're using a Mac
        with an M-series processor, it may fail."""
        "https://files.stork-search.net/releases/v1.5.0/stork-macos-10-15"
    else
        @error "Could not find a precompiled executable of stork-search for your platform."
        nothing
    end

    if url isa String
        download(url, file)
        chmod(Path(file), "+x")
        return file
    else
        throw(SystemError("""Without a precompiled executable, you will need to compile the stork-search CLI
        yourself using the `cargo` toolchain. See https://stork-search.net/docs/install for
        more details.

        After doing so, please pass make sure it is marked executable and pass its path to
        `StorkSearchIndex` using the `stork_bin` keyword argument."""))
    end

end
