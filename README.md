# SimpleUnPack

[![Build Status](https://github.com/devmotion/SimpleUnPack.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/devmotion/SimpleUnPack.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/devmotion/SimpleUnPack.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/devmotion/SimpleUnPack.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

This package provides four macros, namely

- `@unpack` for destructuring properties,
- `@pack!` for setting properties,
- `@unpack_fields` for destructuring fields,
- `@pack_fields!` for setting fields.

`@unpack`/`@pack!` are based on `getproperty`/`setproperty` whereas `@unpack_fields`/`@pack_fields!` are based on `getfield`/`setfield!`.

In Julia >= 1.7.0-DEV.364, `@unpack` is expanded to the destructuring syntax that was introduced in [Julia#39285](https://github.com/JuliaLang/julia/pull/39285).

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

julia> @unpack_fields a, b = f(10)
(b = 10, a = 5.0)

julia> a
5.0

julia> b
10
```

An example with a custom struct in a function:

```julia
julia> using SimpleUnPack

julia> mutable struct MyStruct{X,Y}
           x::X
           y::Y
       end

julia> Base.propertynames(::MyStruct) = (:x, :y)

julia> function Base.getproperty(m::MyStruct, p::Symbol)
           if p === :y
               return 42
           else
               return getfield(m, p)
           end
       end

julia> function Base.setproperty!(m::MyStruct, p::Symbol, v)
           if p === :y
               setfield!(m, p, 2 * v)
           else
               setfield!(m, p, v)
           end
       end

julia> function g(m::MyStruct)
           @unpack x, y = m
           return (; x, y)
       end;

julia> g(MyStruct(1.0, -5))
(x = 1.0, y = 42)

julia> function g!(m::MyStruct, x, y)
          @pack! m = x, y
          return m
       end;

julia> g!(MyStruct(2.1, 5), 1.2, 2)
MyStruct{Float64, Int64}(1.2, 4)

julia> function h(m::MyStruct)
           @unpack_fields x, y = m
           return (; x, y)
       end

julia> h(MyStruct(1.0, -5))
(x = 1.0, y = -5)

julia> function h!(m::MyStruct, x, y)
          @pack_fields! m = x, y
          return m
       end;

julia> h!(MyStruct(2.1, 5), 1.2, 2)
MyStruct{Float64, Int64}(1.2, 2)
```

## Comparison with UnPack.jl

The syntax of `@unpack` and `@pack!` is based on `UnPack.@unpack` and `UnPack.@pack!` in [UnPack.jl](https://github.com/mauro3/UnPack.jl).

`UnPack.@unpack`/`UnPack.@pack!` are more flexible since they are based on `UnPack.unpack`/`UnPack.pack!` instad of `getproperty`/`setproperty!`.
While `UnPack.unpack`/`UnPack.pack!` fall back to `getproperty`/`setproperty!`, they also support `AbstractDict`s with keys of type `Symbol` and `AbstractString` and can be specialized for other types.
Since `UnPack.unpack` and `UnPack.pack!` dispatch on `Val(property)` instances, this increased flexibility comes at the cost of increased number of specializations and increased compilation times.

In contrast to SimpleUnPack, currently UnPack does not support destructuring/updating based on `getfield`/`setfield!` only ([UnPack#23](https://github.com/mauro3/UnPack.jl/issues/23)).
