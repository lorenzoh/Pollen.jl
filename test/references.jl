include("imports.jl")


@testset "referencetype" begin
    @test referencetype(Main, nothing) == :module
    @test referencetype(Base, :π) == :const
    @test referencetype(Base, :sum) == :function
    @test referencetype(Base, :UnitRange) == :ptype
end

referencetype(Base, :sum)

Reference(Base, :sum)
