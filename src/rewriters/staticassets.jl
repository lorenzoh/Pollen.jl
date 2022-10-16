
Base.@kwdef struct StaticAssets <: Rewriter
    resources::Dict{String, String} = Dict{String, String}()
    folder::String = "resources"
end

function rewritedoc(rewriter::StaticAssets, _, doc::Node)
    if haskey(attributes(doc), :path)
        doc_folder = parent(absolute(Path(attributes(doc)[:path])))
        return cata(doc, SelectTag(:img) & SelectHasAttr(:src)) do node
            src = attributes(node)[:src]
            startswith(src, "http") && return node
            file = string(absolute(joinpath(doc_folder, Path(src))))
            key = "$(rewriter.folder)/$(string(hash(file))).$(extension(Path(file)))"
            rewriter.resources[key] = file
            return withattributes(node, merge(attributes(node), Dict(:src => key)))
        end
    else
        return doc
    end
end

function postbuild(rewriter::StaticAssets, _, builder::FileBuilder)
    for (key, srcfile) in rewriter.resources
        dstfile = absolute(joinpath(absolute(builder.dir), key))
        if !isfile(dstfile)
            mkpath(parent(dstfile))
            cp(string(srcfile), string(dstfile), force = true)
        end
    end
end

@testset "StaticAssets [rewriter]" begin mktempdir() do dir
    doc = Node(:md, Node(:img, src = "bla.png"), path = "$dir/doc.md")
    rewriter = StaticAssets()
    outdoc = rewritedoc(rewriter, "", doc)
    @test startswith(attributes(selectfirst(outdoc, SelectTag(:img)))[:src], "resources")
end end
