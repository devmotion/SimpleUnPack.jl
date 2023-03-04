using SimpleUnPack
using Test

struct Property{T}
    x::T
end

Base.propertynames(::Property) = (:x, :y)
function Base.getproperty(x::Property, p::Symbol)
    if p === :y
        return 1.0
    else
        return getfield(x, p)
    end
end

struct Struct{X,Y,Z}
    x::X
    y::Y
    z::Z
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

@testset "SimpleUnPack.jl" begin
    @testset "Variable as RHS" begin
        d = (x=42, y=1.0, z="z")
        @unpack x, z = d
        @test x == 42
        @test z == "z"

        d = Struct(42, 1.0, "z")
        @unpack x, z = d
        @test x == 42
        @test z == "z"

        d = Property(42)
        @unpack y, x = d
        @test x == 42
        @test y == 1.0
    end

    @testset "Expression as RHS" begin
        @unpack x, z = (x=42, y=1.0, z="z")
        @test x == 42
        @test z == "z"

        @unpack x, z = Struct(42, 1.0, "z")
        @test x == 42
        @test z == "z"

        @unpack y, x = Property(42)
        @test x == 42
        @test y == 1.0
    end

    @testset "Type inference" begin
        function f(z)
            @unpack y, x = z
            return x, y
        end
        @test @inferred(f((; y=1.0, z="z", x=42))) == (42, 1.0)
        @test @inferred(f(Struct(42, 1.0, "z"))) == (42, 1.0)
        @test @inferred(f(Property(42))) == (42, 1.0)
    end

    @testset "Errors" begin
        d = (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack d
        @test_macro_throws ArgumentError @unpack (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack x, y, (; x=42, y=1.0)
        @test_macro_throws ArgumentError @unpack x, 1 = (; x=42, y=1.0)
    end
end
