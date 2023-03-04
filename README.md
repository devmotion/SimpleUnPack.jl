# SimpleUnPack

[![Build Status](https://github.com/devmotion/SimpleUnPack.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/devmotion/SimpleUnPack.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/devmotion/SimpleUnPack.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/devmotion/SimpleUnPack.jl)
[![Coverage](https://coveralls.io/repos/github/devmotion/SimpleUnPack.jl/badge.svg?branch=main)](https://coveralls.io/github/devmotion/SimpleUnPack.jl?branch=main)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

This package provides the `@unpack` macro for destructuring properties.
Its behaviour is equivalent to the destructuring that was introduced in [Julia#39285](https://github.com/JuliaLang/julia/pull/39285) and is available in Julia >= 1.7.0-DEV.364.

## Examples

An example with `NamedTuple` in global scope:

```julia
julia> using SimpleUnPack

julia> f(x) = (; b=x, a=x/2);

julia> @unpack a, b = f(42)
(b = 42, a = 21.0)

julia> a
21.0

julia> b
42
```

An example with a custom struct in a function:

```julia
julia> using SimpleUnPack

julia> struct MyStruct{T}
           x::T
       end

julia> Base.getpropertynames(::MyStruct) = (:x, :y)

julia> function Base.getproperty(m::MyStruct, p::Symbol)
           if p === :y
               return 42
           else
               return getfield(m, p)
           end
       end

julia> function g(m::MyStruct)
           @unpack x, y = m
           return (; x, y)
       end;

julia> g(MyStruct(1.0))
(x = 1.0, y = 42)
```

## Comparison with UnPack.jl

The syntax of `@unpack` is based on [`UnPack.@unpack`](https://github.com/mauro3/UnPack.jl).
However, `UnPack.@unpack` is more flexible and based on `UnPack.unpack` instad of `getproperty`.
While `UnPack.unpack` falls back to `getproperty`, it also supports `AbstractDict`s with keys of type `Symbol` and `AbstractString`, and can be specialized for other types.
Since `UnPack.unpack` dispatches on `Val(property)` instances, this increased flexibility comes at the cost of increased compilation times.
Moreover, UnPack also provides an `UnPack.@pack!` macro for setting properties.
