
const PARSECODE_SELECTOR = SelectTag(:codeblock) & SelectAttrEq(:lang, "julia")

Base.@kwdef struct ParseCode <: Rewriter
    selector::Selector = PARSECODE_SELECTOR
    format::Format = JuliaSyntaxFormat()
end

Base.show(io::IO, ::ParseCode) = print(io, "ParseCode()")

function rewritedoc(rewriter::ParseCode, _, doc)
    return cata(doc, rewriter.selector) do x
        code = string(strip(Pollen.gettext(x)))
        return withchildren(x, [parse(code, rewriter.format)])
    end
end

@testset "ParseCode [rewriter]" begin
    rewriter = ParseCode()
    @test rewritedoc(rewriter, "",
                     Node(:md, "hi", Node(:codeblock, "x", lang = "julia"))) ==
          Node(:md, "hi",
               Node(:codeblock,
                    Node(:julia, Node(:Identifier, "x")), lang = "julia"))
end
