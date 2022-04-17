

struct JuliaSyntaxFormat <: Pollen.Format
end


function Pollen.parse(io::IO, ::JuliaSyntaxFormat)
    s = read(io, String)
    isempty(s) && return Node(:julia)
    try
        ast = JuliaSyntax.parseall(JuliaSyntax.GreenNode, s, ignore_trivia=false)
        return withtag(xtree(ast, s), :julia)
    catch e
        @warn "Could not parse code block:\n$s" error = e
        return Node(:julia, s)
    end

end


function xtree(ast::JuliaSyntax.GreenNode, source::String, offset = 1)
    tag = _tokenname(ast)
    if isempty(ast.args)
        return Node(tag, Leaf(Pollen.stringrange(source, offset, ast.span+offset-1)))
    else
        chs = XTree[]
        for ch in ast.args
            push!(chs, xtree(ch, source, offset))
            offset += ch.span
        end

        return Node(tag, chs)
    end
end


function _tokenname(ast::JuliaSyntax.GreenNode) where T
    Base.Enums.namemap(JuliaSyntax.Tokenize.Tokens.Kind)[UInt64(ast.head.kind)]
end


@testset "JuliaSyntaxFormat" begin
    format = JuliaSyntaxFormat()

    @test parse("x+1", format) == Node(:julia, Node(:CALL,
        Node(:IDENTIFIER, "x"),
        Node(:PLUS, "+"),
        Node(:INTEGER, "1"),
    ))


end



function stringrange(s, i1, i2)
    i2 < i1 && return ""
    i1 = _closestindex(s, i1)
    i2 = _closestindex(s, i2)
    return s[i1:i2]
end

function _closestindex(s, i)
    i = min(max(i, 1), ncodeunits(s))
    return prevind(s, i+1)
end
