"""
    @unpack a, b, ... = x

Destructure properties `a`, `b`, ... of `x` into variables of the same name.

The behaviour of the macro is equivalent to `(; a, b, ...) = x` which was introduced in [Julia#39285](https://github.com/JuliaLang/julia/pull/39285) and is available in Julia >= 1.7.0-DEV.364.

See also [`@unpack_fields`](@ref), [`@pack!`](@ref), [`@pack_fields!`](@ref)
"""
macro unpack(args)
    # Extract names of properties and object
    names, object = split_names_object(:unpack, args; object_on_rhs=true)

    # Construct destructuring expression
    expr = if VERSION >= v"1.7.0-DEV.364"
        # Fall back to destructuring in Base when available:
        # https://github.com/JuliaLang/julia/pull/39285
        Expr(:(=), Expr(:tuple, Expr(:parameters, (esc(p) for p in names)...)), esc(object))
    else
        destructuring_expr(:getproperty, names, object)
    end

    return expr
end

"""
    @unpack_fields a, b, ... = x

Destructure fields `a`, `b`, ... of `x` into variables of the same name.

See also [`@unpack`](@ref), [`@pack!`](@ref), [`@pack_fields!`](@ref)
"""
macro unpack_fields(args)
    # Extract names of fields and object
    names, object = split_names_object(:unpack_fields, args; object_on_rhs=true)

    # Construct destructuring expression
    expr = destructuring_expr(:getfield, names, object)

    return expr
end

"""
    destructuring_expr(fsym::Symbol, names, object)

Return an expression that destructures `object` based on a function of name `fsym` and keys `names` into variables of the same `names`.

This function is used internally with `fsym = :getproperty` and `fsym = :getfield`.
"""
function destructuring_expr(fsym::Symbol, names, object)
    @gensym instance
    block = Expr(:block)
    for p in names
        push!(
            block.args, Expr(:(=), esc(p), Expr(:call, fsym, esc(instance), QuoteNode(p)))
        )
    end
    return Base.remove_linenums!(
        quote
            local $(esc(instance)) = $(esc(object)) # In case the object is an expression
            $block
            $(esc(instance)) # Return evaluation of the object
        end,
    )
end
