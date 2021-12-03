struct CSTFormat <: Format end

function parse(s::String, ::CSTFormat)
    return parsecst(s)
end

## Parsing CST expressions to XTrees

parsecst(s::String) = parsecst(s, CSTParser.parse(s, true))

function parsecst(s::String, cst::CSTParser.EXPR, offset::Int = 0)
    head = gethead(cst)
    if head in BRACKETS
        return XNode(:CST_BRACKET, [XLeaf{String}(getcsttext(s, cst, offset))])
    elseif  head in PUNCTUATION
        return XNode(:CST_PUNCTUATION, [XLeaf{String}(getcsttext(s, cst, offset))])
    elseif head in KEYWORDS
        return XNode(:CST_KEYWORD, [XLeaf{String}(getcsttext(s, cst, offset))])
    else
        return parsecst(s, cst, Val(head), offset)
    end
end

# Since CSTParser.jl counts trailing whitespace and comments as belonging to identifiers,
# this utility finds this whitespace and splits it off into its own leaf.
function parsecstwhitespace(tree::XNode)
    sel = SelectTag(:CST_KEYWORD) | SelectTag(:CST_IDENTIFIER)
    return cata(tree, sel) do node
        ch = Pollen.children(node)
        length(ch) == 1 || return node
        ch[1] isa XLeaf{String} || return node
        s::String = ch[1][]

        r = findfirst(r"\s", s)
        isnothing(r) && return node
        i = r.start
        return XNode(
            :CST_span,
            [
                Pollen.withchildren(node, [XLeaf(s[begin:prevind(s, i)])]),
                XNode(:CST_whitespace, [XLeaf(s[i:end])]),
            ],
        )
    end
end


const BRACKETS = Set([:LPAREN, :RPAREN, :LSQUARE, :RSQUARE, :LBRACE, :RBRACE, :ATSIGN])
const PUNCTUATION = Set([:COMMA, :ATSIGN, :DOT])
const KEYWORDS = Set([
    :ABSTRACT,
    :BAREMODULE,
    :BEGIN,
    :BREAK,
    :CATCH,
    :CONST,
    :CONTINUE,
    :DO,
    :ELSE,
    :ELSEIF,
    :END,
    :EXPORT,
    :FINALLY,
    :FOR,
    :FUNCTION,
    :GLOBAL,
    :IF,
    :IMPORT,
    :LET,
    :LOCAL,
    :MACRO,
    :MODULE,
    :MUTABLE,
    :NEW,
    :OUTER,
    :PRIMITIVE,
    :QUOTE,
    :RETURN,
    :STRUCT,
    :TRY,
    :TYPE,
    :USING,
    :WHILE,
])

function parsecst(s::String, cst::CSTParser.EXPR, ::Val, offset::Int)
    tag = Symbol("CST_" * string(gethead(cst)))
    return XNode(tag, parsecstchildren(s, cst, offset))
end

function parsecstchildren(s::String, cst::CSTParser.EXPR, offset = 0)
    if isempty(getchildren(cst))
        return XTree[XLeaf(getcsttext(s, cst, offset))]
    else
        # scan offsets
        offsets = Int[]
        o = offset
        for child in getchildren(cst)
            push!(offsets, o)
            o += child.fullspan
        end
        return XTree[parsecst(s, child, o) for (child, o) in zip(getchildren(cst), offsets)]
    end
end

function getcsttext(s, cst, offset = 0)
    i1 = offset+1
    i2 = nextind(s, prevind(s, max(1, offset+cst.fullspan)))
    i2 = min(i2, lastindex(s))
    return s[i1:i2]
end

getchildren(cst::CSTParser.EXPR) = collect(cst)
gethead(cst::CSTParser.EXPR) = gethead(CSTParser.headof(cst))
gethead(s::Symbol) = s
