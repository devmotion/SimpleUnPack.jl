using SimpleUnPack
using Test

mutable struct Property{X,Y,Z}
    x::X
    y::Y
    z::Z
end

Base.propertynames(::Property) = (:x, :y, :z)
function Base.getproperty(x::Property, p::Symbol)
    if p === :z
        return "z"
    else
        return getfield(x, p)
    end
end
function Base.setproperty!(x::Property, p::Symbol, val)
    if p === :z
        setfield!(x, p, val^2)
    else
        setfield!(x, p, val)
    end
end

mutable struct Struct{X,Y,Z}
    x::X
    y::Y
    z::Z
end

# Define equality (simplifies test code below)
for T in (:Property, :Struct)
    @eval begin
        Base.:(==)(x::$T, y::$T) = x.x == y.x && x.y == y.y && x.z == y.z
        function Base.isequal(x::$T, y::$T)
            return isequal(x.x, y.x) && isequal(x.y, y.y) && isequal(x.z, y.z)
        end
    end
end

# Copied from ChainRulesCore: Test if a macro throws an error when it is expanded
macro test_macro_throws(err_expr, expr)
    quote
        err = try
            @macroexpand($(esc(expr)))
            nothing
        catch _err
            # https://github.com/JuliaLang/julia/pull/38379
            if VERSION >= v"1.7.0-DEV.937"
                _err
            else
                # until Julia v1.7
                # all errors thrown at macro expansion time are LoadErrors, we need to unwrap
                @assert _err isa LoadError
                _err.error
            end
        end
        # Reuse `@test_throws` logic
        if err !== nothing
            @test_throws $(esc(err_expr)) ($(Meta.quot(expr)); throw(err))
        else
            @test_throws $(esc(err_expr)) $(Meta.quot(expr))
        end
    end
end

# Module for testing behaviour in global scope (issue #3)
baremodule A
using SimpleUnPack
@unpack a = (a=1.5, b=3)
end

@testset "SimpleUnPack.jl" begin
    @testset "Variable as LHS/RHS" begin
        d = (x=42, y=1.0, z="z1")
        @unpack x, z = d
        @test x == 42
        @test z == "z1"
        @unpack y = d
        @test y == 1.0

        d = (x=43, y=2.0, z="z2")
        @unpack_fields x, z = d
        @test x == 43
        @test z == "z2"
        @unpack_fields y = d
        @test y == 2.0

        d = Struct(44, 3.0, "z3")
        @pack! d = x, z
        @test d == Struct(43, 3.0, "z2")
        @pack! d = y
        @test d == Struct(43, 2.0, "z2")

        d = Struct(44, 3.0, "z3")
        @unpack x, z = d
        @test x == 44
        @test z == "z3"
        @unpack y = d
        @test y == 3.0

        d = Struct(45, 4.0, "z4")
        @pack_fields! d = x, z
        @test d == Struct(44, 4.0, "z3")
        @pack_fields! d = y
        @test d == Struct(44, 3.0, "z3")

        d = Struct(45, 4.0, "z4")
        @unpack_fields x, z = d
        @test x == 45
        @test z == "z4"
        @unpack_fields y = d
        @test y == 4.0

        d = Property(46, 5.0, "z5")
        @pack! d = x, z
        @test d == Property(45, 5.0, "z5z5")
        @pack! d = y
        @test d == Property(45, 4.0, "z5z5")

        d = Property(46, 5.0, "z5")
        @unpack x, z = d
        @test x == 46
        @test z == "z"
        @unpack y = d
        @test y == 5.0

        d = Property(47, 6.0, "z6")
        @pack_fields! d = x, z
        @test d == Property(46, 6.0, "z")
        @pack_fields! d = y
        @test d == Property(46, 5.0, "z")

        d = Property(47, 6.0, "z6")
        @unpack_fields x, z = d
        @test x == 47
        @test z == "z6"
        @unpack_fields y = d
        @test y == 6.0
    end

    @testset "Expression as LHS/RHS" begin
        @unpack x, z = (x=42, y=1.0, z="z1")
        @test x == 42
        @test z == "z1"
        @unpack y = (x=42, y=1.0, z="z1")
        @test y == 1.0

        @unpack_fields x, z = (x=43, y=2.0, z="z2")
        @test x == 43
        @test z == "z2"
        @unpack_fields y = (x=43, y=2.0, z="z2")
        @test y == 2.0

        @unpack x, z = Struct(44, 3.0, "z3")
        @test x == 44
        @test z == "z3"
        @unpack y = Struct(44, 3.0, "z3")
        @test y == 3.0

        @unpack_fields x, z = Struct(45, 4.0, "z4")
        @test x == 45
        @test z == "z4"
        @unpack_fields y = Struct(45, 4.0, "z4")
        @test y == 4.0

        @unpack x, z = Property(46, 5.0, "z5")
        @test x == 46
        @test z == "z"
        @unpack y = Property(46, 5.0, "z5")
        @test y == 5.0

        @unpack_fields x, z = Property(47, 6.0, "z6")
        @test x == 47
        @test z == "z6"
        @unpack_fields y = Property(47, 6.0, "z6")
        @test y == 6.0
    end

    @testset "Type inference" begin
        function f(a)
            @unpack y, z, x = a
            return x, y, z
        end
        @test @inferred(f((; y=1.0, z="a", x=42))) == (42, 1.0, "a")
        @test @inferred(f(Struct(42, 1.0, "a"))) == (42, 1.0, "a")
        @test @inferred(f(Property(42, 1.0, "a"))) == (42, 1.0, "z")

        function g(a)
            @unpack_fields y, z, x = a
            return x, y, z
        end
        @test @inferred(g((; y=1.0, z="a", x=42))) == (42, 1.0, "a")
        @test @inferred(g(Struct(42, 1.0, "a"))) == (42, 1.0, "a")
        @test @inferred(g(Property(42, 1.0, "a"))) == (42, 1.0, "a")
    end

    @testset "Errors" begin
        d = (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack d
        @test_macro_throws ArgumentError @unpack (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack x, y, (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack x, 1 = (; x=42, y=1.0)

        @test_macro_throws ArgumentError @unpack_fields d
        @test_macro_throws ArgumentError @unpack_fields (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack_fields x, y, (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack_fields x, 1 = (; x=42, y=1.0)
    end

    @testset "global scope (issue #3)" begin
        @test names(A; all=true) == [:A, :a]
    end
end
