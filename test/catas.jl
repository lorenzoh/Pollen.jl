include("imports.jl")

@testset ExtendedTestSet "catafirst" begin
    x = XNode(:body, [XLeaf(1), XLeaf(2)])

    x_ = cata(x, SelectLeaf()) do leaf
        return XLeaf(leaf[] + 1)
    end
    @test children(x_)[1][] == 2
    @test children(x_)[2][] == 3

    x__ = catafirst(x, SelectLeaf()) do leaf
        return XLeaf(leaf[] + 1)
    end
    @test children(x__)[1][] == 2
    @test children(x__)[2][] == 2
end


@testset ExtendedTestSet "replace" begin
    x = XNode(:body, [XLeaf(1), XLeaf(2)])
    node = XNode(:body)
    @test Pollen.replace(x, node, SelectNode()) == node

    x_ = Pollen.replacefirst(x, node, SelectLeaf())
    @test tag(x_) == :body
    @test tag(children(x_)[1]) == :body
end


@testset ExtendedTestSet "insert" begin
    x = XNode(:body, [XLeaf(1), XLeaf(2)])
    @testset ExtendedTestSet "NthChild" begin
        x_ = insert(x, XLeaf(0), NthChild(1, SelectNode()))
        @test children(x_) == XLeaf.(0:2)
        @test insert(x, XLeaf(0), NthChild(1, SelectNode())) == insertfirst(x, XLeaf(0), NthChild(1, SelectNode()))
    end

    @testset ExtendedTestSet "Before" begin
        x_ = insert(x, XLeaf(0), Before(SelectLeaf()))
        @test children(x_) == XLeaf.(0:2)
    end

    @testset ExtendedTestSet "Before" begin
        x_ = insert(x, XLeaf(0), After(SelectLeaf()))
        @test children(x_) == XLeaf.([1, 0, 2])
    end
end


@testset ExtendedTestSet "gettext" begin
    x = XNode(:body, XLeaf.(["Hello", " ", "World"]))
    @test Pollen.gettext(x) == "Hello World"
end
