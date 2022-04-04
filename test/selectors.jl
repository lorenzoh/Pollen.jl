include("imports.jl")


@testset "Selectors" begin
    node = Node(:body, Dict(:class => "content"), [Leaf(1), Leaf(2)])
    leaf = children(node)[1]
    @test matches(SelectTag(:body), node)
    @test !matches(SelectTag(:div), node)
    @test matches(!SelectTag(:div), node)
    @test matches(SelectTag(:div) | SelectTag(:body), node)
    @test matches(SelectLeaf(), leaf)
    @test matches(SelectNode(), node)
    @test matches(SelectHasAttr(:class), node)
    @test matches(SelectAttrEq(:class, "content"), node)
end
