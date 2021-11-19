struct ParseCode <: Rewriter
end


function rewritedoc(parse::ParseCode, path, doc)
    return cata(doc, SelectTag(:codeblock)) do x
        code = string(strip(Pollen.gettext(x)))
        ch = children(Pollen.parse(code, CSTFormat()))
        ch = map(cleantopleveldefinition, ch)
        return withchildren(x, ch)
    end
end
