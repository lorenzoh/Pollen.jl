struct ParseCode <: Rewriter
end


function rewritedoc(::ParseCode, _, doc)
    return cata(doc, SelectTag(:codeblock)) do x
        code = string(strip(Pollen.gettext(x)))
        ch = children(Pollen.parse(code, CSTFormat()))
        ch = map(cleantopleveldefinition, ch)
        return parsecstwhitespace(withchildren(x, ch))
    end
end
