module SimpleUnPack

export @unpack, @unpack_fields

"""
    @unpack a, b, ... = x

Destructure properties `a`, `b`, ... of `x` into variables of the same name.

The behaviour of the macro is equivalent to `(; a, b, ...) = x` which was introduced in [Julia#39285](https://github.com/JuliaLang/julia/pull/39285) and is available in Julia >= 1.7.0-DEV.364.

See also [`@unpack_fields`](@ref)
"""
macro unpack(args)
    # Extract names of properties and RHS
    names, rhs = split_names_rhs(:unpack, args)

    # Construct destructuring expression
    expr = if VERSION >= v"1.7.0-DEV.364"
        # Fall back to destructuring in Base when available:
        # https://github.com/JuliaLang/julia/pull/39285
        Expr(:(=), Expr(:tuple, Expr(:parameters, (esc(p) for p in names)...)), esc(rhs))
    else
        destructuring_expr(:getproperty, names, rhs)
    end

    return expr
end

"""
    @unpack_fields a, b, ... = x

Destructure fields `a`, `b`, ... of `x` into variables of the same name.

See also [`@unpack`](@ref)
"""
macro unpack_fields(args)
    # Extract names of fields and RHS
    names, rhs = split_names_rhs(:unpack_fields, args)

    # Construct destructuring expression
    expr = destructuring_expr(:getfield, names, rhs)

    return expr
end

"""
    split_names_rhs(macrosym::Symbol, expr)

Split an expression `expr` of the form `a, b, ... = x` into a tuple consisting of a vector of symbols `a`, `b`, ..., and the right-hand side `x`.

The symbol `macro_name` specifies the macro from which this function is called.

This function is used internally with `macrosym = :unpack` and `macrosym = :unpack_fields`.
"""
function split_names_rhs(macrosym::Symbol, expr)
    if !Meta.isexpr(expr, :(=), 2)
        throw(
            ArgumentError(
                "`@$macrosym` can only be applied to expressions of the form `a, b, ... = x`",
            ),
        )
    end
    lhs, rhs = expr.args
    names = if lhs isa Symbol
        [lhs]
    elseif Meta.isexpr(lhs, :tuple) &&
        !isempty(lhs.args) &&
        all(x -> x isa Symbol, lhs.args)
        lhs.args
    else
        throw(
            ArgumentError(
                "`@$macrosym` can only be applied to expressions of the form `a, b, ... = x`",
            ),
        )
    end
    return names, rhs
end

"""
    destructuring_expr(fsym::Symbol, names, rhs)

Return an expression that destructures `rhs` based on a function of name `fsym` and keys `names` into variables of the same `names`.

This function is used internally with `fsym = :getproperty` and `fsym = :getfield`.
"""
function destructuring_expr(fsym::Symbol, names, rhs)
    @gensym object
    block = Expr(:block)
    for p in names
        push!(block.args, Expr(:(=), esc(p), Expr(:call, fsym, esc(object), QuoteNode(p))))
    end
    return Base.remove_linenums!(
        quote
            $(esc(object)) = $(esc(rhs)) # In case the RHS is an expression
            $block
            $(esc(object)) # Return evaluation of the RHS
        end,
    )
end

end # module
