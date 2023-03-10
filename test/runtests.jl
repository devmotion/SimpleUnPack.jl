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

# Modules for testing behaviour in global scope (issue #3)
baremodule A
using SimpleUnPack
@unpack a = (a=1.5, b=3)
@unpack_fields b = (a=1.5, b=3)
end

baremodule B
using SimpleUnPack
mutable struct Struct{T}
    x::T
    y::T
end
const x = 2.5
const y = 7.2
@pack! Struct(0.0, 0.0) = x
@pack_fields! Struct(0.0, 0.0) = x, y
end

@testset "SimpleUnPack.jl" begin
    @testset "Variable as LHS/RHS" begin
        local x, y, z

        d = (x=42, y=1.0, z="z1")
        @test (@unpack x, z = d) == d
        @test x == 42
        @test z == "z1"
        @test (@unpack y = d) == d
        @test y == 1.0

        d = (x=43, y=2.0, z="z2")
        @test (@unpack_fields x, z = d) == d
        @test x == 43
        @test z == "z2"
        @test (@unpack_fields y = d) == d
        @test y == 2.0

        d = Struct(44, 3.0, "z3")
        @test (@pack! d = x, z) == (x, z)
        @test d == Struct(43, 3.0, "z2")
        @test (@pack! d = y) == y
        @test d == Struct(43, 2.0, "z2")

        d = Struct(44, 3.0, "z3")
        @test (@unpack x, z = d) == d
        @test x == 44
        @test z == "z3"
        @test (@unpack y = d) == d
        @test y == 3.0

        d = Struct(45, 4.0, "z4")
        @test (@pack_fields! d = x, z) == (x, z)
        @test d == Struct(44, 4.0, "z3")
        @test (@pack_fields! d = y) == y
        @test d == Struct(44, 3.0, "z3")

        d = Struct(45, 4.0, "z4")
        @test (@unpack_fields x, z = d) == d
        @test x == 45
        @test z == "z4"
        @test (@unpack_fields y = d) == d
        @test y == 4.0

        d = Property(46, 5.0, "z5")
        @test (@pack! d = x, z) == (x, "z4z4")
        @test d == Property(45, 5.0, "z5z5")
        @test (@pack! d = y) == y
        @test d == Property(45, 4.0, "z5z5")

        d = Property(46, 5.0, "z5")
        @test (@unpack x, z = d) == d
        @test x == 46
        @test z == "z"
        @test (@unpack y = d) == d
        @test y == 5.0

        d = Property(47, 6.0, "z6")
        @test (@pack_fields! d = x, z) == (x, z)
        @test d == Property(46, 6.0, "z")
        @test (@pack_fields! d = y) == y
        @test d == Property(46, 5.0, "z")

        d = Property(47, 6.0, "z6")
        @test (@unpack_fields x, z = d) == d
        @test x == 47
        @test z == "z6"
        @test (@unpack_fields y = d) == d
        @test y == 6.0
    end

    @testset "Expression as LHS/RHS" begin
        local x, y, z

        @test (@unpack x, z = (x=42, y=1.0, z="z1")) == (x=42, y=1.0, z="z1")
        @test x == 42
        @test z == "z1"
        @test (@unpack y = (x=42, y=1.0, z="z1")) == (x=42, y=1.0, z="z1")
        @test y == 1.0

        @test (@unpack_fields x, z = (x=43, y=2.0, z="z2")) == (x=43, y=2.0, z="z2")
        @test x == 43
        @test z == "z2"
        @test (@unpack_fields y = (x=43, y=2.0, z="z2")) == (x=43, y=2.0, z="z2")
        @test y == 2.0

        d = Struct(44, 3.0, "z3")
        @test (@pack! (d.y = 4.0; d) = x, z) == (x, z)
        @test d == Struct(43, 4.0, "z2")
        @test (@pack! (d.x = 44; d) = y) == y
        @test d == Struct(44, 2.0, "z2")

        @test (@unpack x, z = Struct(44, 3.0, "z3")) == Struct(44, 3.0, "z3")
        @test x == 44
        @test z == "z3"
        @test (@unpack y = Struct(44, 3.0, "z3")) == Struct(44, 3.0, "z3")
        @test y == 3.0

        d = Struct(45, 4.0, "z4")
        @test (@pack_fields! (d.y = 5.0; d) = x, z) == (x, z)
        @test d == Struct(44, 5.0, "z3")
        @test (@pack_fields! (d.x = 45; d) = y) == y
        @test d == Struct(45, 3.0, "z3")

        @test (@unpack_fields x, z = Struct(45, 4.0, "z4")) == Struct(45, 4.0, "z4")
        @test x == 45
        @test z == "z4"
        @test (@unpack_fields y = Struct(45, 4.0, "z4")) == Struct(45, 4.0, "z4")
        @test y == 4.0

        d = Property(46, 5.0, "z5")
        @test (@pack! (d.y = 6.0; d) = x, z) == (x, "z4z4")
        @test d == Property(45, 6.0, "z4z4")
        @test (@pack! (d.x = 46; d) = y) == y
        @test d == Property(46, 4.0, "z4z4")

        @test (@unpack x, z = Property(46, 5.0, "z5")) == Property(46, 5.0, "z5")
        @test x == 46
        @test z == "z"
        @test (@unpack y = Property(46, 5.0, "z5")) == Property(46, 5.0, "z5")
        @test y == 5.0

        d = Property(47, 6.0, "z6")
        @test (@pack_fields! (d.y = 7.0; d) = x, z) == (x, "z")
        @test d == Property(46, 7.0, "z")
        @test (@pack_fields! (d.x = 47; d) = y) == y
        @test d == Property(47, 5.0, "z")

        @test (@unpack_fields x, z = Property(47, 6.0, "z6")) == Property(47, 6.0, "z6")
        @test x == 47
        @test z == "z6"
        @test (@unpack_fields y = Property(47, 6.0, "z6")) == Property(47, 6.0, "z6")
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

        function f!(a, x, y, z)
            return @pack! a = x, z, y
        end
        a = Struct(42, 1.0, "a")
        @test @inferred(f!(a, 43, 2.0, "b")) == (43, "b", 2.0)
        @test a == Struct(43, 2.0, "b")
        a = Property(42, 1.0, "a")
        @test @inferred(f!(a, 43, 2.0, "b")) == (43, "bb", 2.0)
        @test a == Property(43, 2.0, "bb")

        function g(a)
            @unpack_fields y, z, x = a
            return x, y, z
        end
        @test @inferred(g((; y=1.0, z="a", x=42))) == (42, 1.0, "a")
        @test @inferred(g(Struct(42, 1.0, "a"))) == (42, 1.0, "a")
        @test @inferred(g(Property(42, 1.0, "a"))) == (42, 1.0, "a")

        function g!(a, x, y, z)
            return @pack_fields! a = x, z, y
        end
        a = Struct(42, 1.0, "a")
        @test @inferred(g!(a, 43, 2.0, "b")) == (43, "b", 2.0)
        @test a == Struct(43, 2.0, "b")
        a = Property(42, 1.0, "a")
        @test @inferred(g!(a, 43, 2.0, "b")) == (43, "b", 2.0)
        @test a == Property(43, 2.0, "b")
    end

    @testset "Errors" begin
        d = (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack d
        @test_macro_throws ArgumentError @unpack (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack x, y, (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack x, 1 = (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack (; x=42, y=1.0) = x, y

        @test_macro_throws ArgumentError @unpack_fields d
        @test_macro_throws ArgumentError @unpack_fields (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack_fields x, y, (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack_fields x, 1 = (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack_fields (; x=42, y=1.0) = x, y

        d = Struct(42, 1.0, "a")
        @test_macro_throws ArgumentError @pack! d
        @test_macro_throws ArgumentError @pack! Struct(42, 1.0, "a")
        @test_macro_throws ArgumentError @pack! Struct(42, 1.0, "a"), x, y
        @test_macro_throws ArgumentError @pack! Struct(42, 1.0, "a") = x, 1
        @test_macro_throws ArgumentError @pack! x, y = Struct(42, 1.0, "a")

        @test_macro_throws ArgumentError @pack_fields! d
        @test_macro_throws ArgumentError @pack_fields! Struct(42, 1.0, "a")
        @test_macro_throws ArgumentError @pack_fields! Struct(42, 1.0, "a"), x, y
        @test_macro_throws ArgumentError @pack_fields! Struct(42, 1.0, "a") = x, 1
        @test_macro_throws ArgumentError @pack_fields! x, y = Struct(42, 1.0, "a")
    end

    @testset "global scope (issue #3)" begin
        @test names(A; all=true) == [:A, :a, :b]
        @test names(B; all=true) == [:B, :Struct, :x, :y]
    end
end
