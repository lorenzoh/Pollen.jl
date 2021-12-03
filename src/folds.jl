function gettext(x, sep="")
    return fold(x, "") do s, x
        if x isa XLeaf && x[] isa AbstractString
            return s * sep * x[]
        else
            return s
        end
    end
end
