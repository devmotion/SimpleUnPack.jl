module SimpleUnPack

export @unpack, @unpack_fields, @pack!, @pack_fields!

"""
    @unpack a, b, ... = x

Destructure properties `a`, `b`, ... of `x` into variables of the same name.

The behaviour of the macro is equivalent to `(; a, b, ...) = x` which was introduced in [Julia#39285](https://github.com/JuliaLang/julia/pull/39285) and is available in Julia >= 1.7.0-DEV.364.

See also [`@pack!`](@ref), [`@unpack_fields`](@ref), [`@pack_fields!`](@ref)
"""
macro unpack(args)
    # Extract names of properties and object
    names, object = split_names_object(:unpack, args, true)

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
    @pack! x = a, b, ...

Set properties `a`, `b`, ... of `x` to the given values.

See also [`@unpack`](@ref), [`@unpack_fields`](@ref), [`@pack_fields!`](@ref)
"""
macro pack!(args)
    # Extract names of properties and the object that will be updated
    names, object = split_names_object(:pack!, args, false)

    # Construct updating expression
    expr = updating_expr(:setproperty!, object, names)

    return expr
end

"""
    @unpack_fields a, b, ... = x

Destructure fields `a`, `b`, ... of `x` into variables of the same name.

See also [`@pack_fields!`](@ref), [`@unpack`](@ref), [`@pack!`](@ref)
"""
macro unpack_fields(args)
    # Extract names of fields and object
    names, object = split_names_object(:unpack_fields, args, true)

    # Construct destructuring expression
    expr = destructuring_expr(:getfield, names, object)

    return expr
end

"""
    @pack_fields! x = a, b, ...

Set fields `a`, `b`, ... of `x` to the given values.

See also [`@unpack_fields`](@ref), [`@unpack`](@ref), [`@pack!`](@ref)
"""
macro pack_fields!(args)
    # Extract names of properties and the object that will be updated
    names, object = split_names_object(:pack_fields!, args, false)

    # Construct updating expression
    expr = updating_expr(:setfield!, object, names)

    return expr
end

"""
    split_names_object(macrosym::Symbol, expr, object_on_rhs::Bool)

Split an expression `expr` of the form `a, b, ... = x` (if `object_on_rhs = true`) or `x = a, b, ...` (if `object_on_rhs = false`) into a tuple consisting of a vector of symbols `a`, `b`, ..., and the expression or symbol for `x`.

The symbol `macro_name` specifies the macro from which this function is called.

This function is used internally with `macrosym = :unpack`, `macrosym = :unpack_fields`, `macrosym = :pack!`, and `macrosym = :pack_fields!`.
"""
function split_names_object(macrosym::Symbol, expr, object_on_rhs::Bool)
    if !Meta.isexpr(expr, :(=), 2)
        throw(
            ArgumentError(
                "`@$macrosym` can only be applied to expressions of the form " *
                (object_on_rhs ? "`a, b, ... = x`" : "`x = a, b, ...`"),
            ),
        )
    end
    lhs, rhs = expr.args
    names_side = object_on_rhs ? lhs : rhs
    names = if names_side isa Symbol
        [names_side]
    elseif Meta.isexpr(names_side, :tuple) &&
        !isempty(names_side.args) &&
        all(x -> x isa Symbol, names_side.args)
        names_side.args
    else
        throw(
            ArgumentError(
                "`@$macrosym` can only be applied to expressions of the form " *
                (object_on_rhs ? "`a, b, ... = x`" : "`x = a, b, ...`"),
            ),
        )
    end
    object = object_on_rhs ? rhs : lhs
    return names, object
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

"""
    updating_expr(fsym::Symbol, object, names)

Return an expression that updates keys `names` of `object` with variables of the same `names` based on a function of name `fsym`.

This function is used internally with `fsym = :setproperty!` and `fsym = :setfield!`.
"""
function updating_expr(fsym::Symbol, object, names)
    @gensym instance
    block = Expr(:block)
    for p in names
        push!(block.args, Expr(:call, fsym, esc(instance), QuoteNode(p), esc(p)))
    end
    return Base.remove_linenums!(
        quote
            local $(esc(instance)) = $(esc(object)) # In case the object is an expression
            $block
            ($(map(esc, names)...),)
        end,
    )
end

end # module
