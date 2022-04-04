include("imports.jl")

@testset "catafirst" begin
    x = Node(:body, [Leaf(1), Leaf(2)])

    x_ = cata(x, SelectLeaf()) do leaf
        return Leaf(leaf[] + 1)
    end
    @test children(x_)[1][] == 2
    @test children(x_)[2][] == 3

    x__ = catafirst(x, SelectLeaf()) do leaf
        return Leaf(leaf[] + 1)
    end
    @test children(x__)[1][] == 2
    @test children(x__)[2][] == 2
end


@testset "replace" begin
    x = Node(:body, [Leaf(1), Leaf(2)])
    node = Node(:body)
    @test Pollen.replace(x, node, SelectNode()) == node

    x_ = Pollen.replacefirst(x, node, SelectLeaf())
    @test tag(x_) == :body
    @test tag(children(x_)[1]) == :body
end


@testset "insert" begin
    x = Node(:body, [Leaf(1), Leaf(2)])
    @testset "NthChild" begin
        x_ = insert(x, Leaf(0), NthChild(1, SelectNode()))
        @test children(x_) == Leaf.(0:2)
        @test insert(x, Leaf(0), NthChild(1, SelectNode())) == insertfirst(x, Leaf(0), NthChild(1, SelectNode()))
    end

    @testset "Before" begin
        x_ = insert(x, Leaf(0), Before(SelectLeaf()))
        @test children(x_) == Leaf.(0:2)
    end

    @testset "Before" begin
        x_ = insert(x, Leaf(0), After(SelectLeaf()))
        @test children(x_) == Leaf.([1, 0, 2])
    end
end


@testset "gettext" begin
    x = Node(:body, Leaf.(["Hello", " ", "World"]))
    @test Pollen.gettext(x) == "Hello World"
end
