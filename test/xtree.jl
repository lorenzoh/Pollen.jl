include("imports.jl")



@testset "XTree constructors" begin
    @test_nowarn Node(:tag)
    @test_throws MethodError Node(:tag, [])
    @test_nowarn Node(:tag, Leaf.(1:10))

end

@testset "fold" begin
    x = Node(:tag, Leaf.(1:10))
    @test foldleaves(+, x, 0) == sum(1:10)
end


@testset "cata" begin
    x = Node(:tag, Leaf.(1:10))
    x_ = cata(x) do node
        if node isa Leaf
            return Leaf(-node[])
        else
            return node
        end
    end
    @test x_ == Node(:tag, Leaf.(-1:-1:-10))
end


@testset "catafold" begin
    x = Node(:tag, Leaf.(1:10))
    x_, n = catafold(x, 0) do node, state
        if node isa Leaf
            return Leaf(-node[]), state + 1
        else
            return node, state
        end
    end
    @test x_ == Node(:tag, Leaf.(-1:-1:-10))
    @test n == 10
end
