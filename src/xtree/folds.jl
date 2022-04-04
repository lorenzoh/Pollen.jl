function gettext(x)
    return fold(x, "") do s, x
        if x isa Leaf && x[] isa AbstractString
            return s * x[]
        else
            return s
        end
    end
end
