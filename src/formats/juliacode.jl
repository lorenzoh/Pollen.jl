
struct JuliaCodeFormat <: Pollen.Format end

function Pollen.parse(source::String, ::JuliaCodeFormat)
    blocks = splitcodeandcomments(source)
    chs = XTree[]
    for block in blocks
        content = string(strip(block.content))
        if length(content) == 0
            continue
        end
        if block.iscomment
            ch = children(Pollen.parse(content, Pollen.Markdown()))
            attrs = Dict(:startline => block.startline, :endline => block.endline)

            push!(chs, Node(:comment, attrs, ch))
        else
            attrs = Dict(:startline => block.startline, :endline => block.endline)
            push!(chs, Node(:codeblock, attrs, [Leaf(content)]))
        end
    end

    return Node(:sourcefile, chs)
end

##

function cleantopleveldefinition(doc)
    doc isa Leaf && return doc
    ch = children(doc)
    if iscomment(doc)
        return withtag(doc, :CST_COMMENT)
    elseif isdocdefinition(doc)
        return Node(:CST_DEFINITION, Dict(:docstring => Pollen.gettext(ch[3])), [ch[4]])
    elseif isdefinition(doc)
        return Node(:CST_DEFINITION, [doc])
    else
        return doc
    end
end

iscomment(doc) = tag(doc) == :CST_NOTHING && !isempty(children(doc))

function isdocdefinition(doc)
    ch = children(doc)
    (tag(doc) == :CST_macrocall) &&
        length(ch) == 4 &&
        tag(ch[1]) == :CST_globalrefdoc &&
        tag(ch[2]) ∈ (:CST_NOTHING, :CST_COMMENT) &&
        tag(ch[3]) == :CST_TRIPLESTRING

end

function isdefinition(doc)
    ch = children(doc)
    return true
end


struct SourceBlock
    content::String
    startline::Int
    endline::Int
    iscomment::Bool
end

iscommentline(line) = startswith(line, "#")

function splitcodeandcomments(source)
    blocks = SourceBlock[]
    lines = split(source, '\n')
    iscomments = findcommentlines(lines)

    startline = 1
    iscomment = iscomments[1]
    while startline <= length(lines)
        i = findnext(!=(iscomment), iscomments, startline)
        i = isnothing(i) ? length(lines) + 1 : i
        push!(
            blocks,
            SourceBlock(
                join([iscomment ? l[2:end] : l for l in lines[startline:i-1]], '\n'),
                startline,
                i - 1,
                iscomment,
            ),
        )
        startline = i
        iscomment = !iscomment
    end

    return blocks
end


function findcommentlines(lines)
    istriplequote = false
    isblockcomment = false
    iscomment = false
    res = Bool[]
    for line in lines
        if !isblockcomment && startswith(strip(line), "\"\"\"")
            istriplequote = !istriplequote
        end
        if !isblockcomment && startswith(strip(line), "#=")
            isblockcomment = true
        elseif isblockcomment && endswith(strip(line), "#=")
            isblockcomment = false
        end

        push!(res, (isblockcomment || (!istriplequote && startswith(line, "#"))))
    end
    res
end
