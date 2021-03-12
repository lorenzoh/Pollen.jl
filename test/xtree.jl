include("imports.jl")



@testset ExtendedTestSet "XTree constructors" begin

    @test_nowarn XNode(:tag)
    @test_throws MethodError XNode(:tag, [])
    @test_nowarn XNode(:tag, XLeaf.(1:10))

end

@testset ExtendedTestSet "fold" begin
    x = XNode(:tag, XLeaf.(1:10))
    @test foldleaves(+, x, 0) == sum(1:10)
end


@testset ExtendedTestSet "cata" begin
    x = XNode(:tag, XLeaf.(1:10))
    x_ = cata(x) do node
        if node isa XLeaf
            return XLeaf(-node[])
        else
            return node
        end
    end
    @test x_ == XNode(:tag, XLeaf.(-1:-1:-10))
end


@testset ExtendedTestSet "catafold" begin
    x = XNode(:tag, XLeaf.(1:10))
    x_, n = catafold(x, 0) do node, state
        if node isa XLeaf
            return XLeaf(-node[]), state + 1
        else
            return node, state
        end
    end
    @test x_ == XNode(:tag, XLeaf.(-1:-1:-10))
    @test n == 10
end
