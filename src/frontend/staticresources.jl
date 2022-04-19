
Base.@kwdef struct StaticResources <: Rewriter
    resources::Dict{String, String} = Dict{String, String}()
    folder::String = "resources"
end


function rewritedoc(rewriter::StaticResources, _, doc::Node)
    if haskey(attributes(doc), :path)
        doc_folder = parent(absolute(Path(attributes(doc)[:path])))
        return cata(doc, SelectTag(:img) & SelectHasAttr(:src)) do node
            file = string(absolute(joinpath(doc_folder, Path(attributes(node)[:src]))))
            key = "$(rewriter.folder)/$(string(hash(file))).$(extension(Path(file)))"
            rewriter.resources[key] = file
            return withattributes(node, merge(attributes(node), Dict(:src => key)))
        end
    else
        return doc
    end
end

function postbuild(rewriter::StaticResources, _, builder::FileBuilder)
    for (key, srcfile) in rewriter.resources
        dstfile = absolute(joinpath(absolute(builder.dir), key))
        if !isfile(dstfile)
            mkpath(parent(dstfile))
            cp(string(srcfile), string(dstfile), force = true)
        end
    end
end


@testset "StaticResources [rewriter]" begin
    mktempdir() do dir
        doc = Node(:md, Node(:img, src = "bla.png"), path = "$dir/doc.md")
        rewriter = StaticResources()
        outdoc = rewritedoc(rewriter, "", doc)
        @test startswith(attributes(selectfirst(outdoc, SelectTag(:img)))[:src], "resources")
    end
end
