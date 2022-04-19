function gettext(x, sep="")
    return fold(x, "") do s, x
        if x isa Leaf && x[] isa AbstractString
            return s * sep * x[]
        else
            return s
        end
    end
end
