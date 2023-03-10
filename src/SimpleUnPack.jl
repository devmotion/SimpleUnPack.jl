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
    # Split expression in LHS and RHS
    if !Meta.isexpr(expr, :(=), 2)
        throw(
            ArgumentError(
                "`@$macrosym` can only be applied to expressions of the form " *
                (object_on_rhs ? "`a, b, ... = x`" : "`x = a, b, ...`"),
            ),
        )
    end
    lhs, rhs = expr.args

    # Clean expression with keys a bit:
    # Remove line numbers and unwrap it from `:block` expression
    names_expr = object_on_rhs ? lhs : rhs
    Base.remove_linenums!(names_expr)
    if Meta.isexpr(names_expr, :block, 1)
        names_expr = names_expr.args[1]
    end

    # Ensure that names are given as symbol or tuple of symbols,
    # and convert them to a vector of symbols
    names = if names_expr isa Symbol
        [names_expr]
    elseif Meta.isexpr(names_expr, :tuple) &&
        !isempty(names_expr.args) &&
        all(x -> x isa Symbol, names_expr.args)
        names_expr.args
    else
        throw(
            ArgumentError(
                "`@$macrosym` can only be applied to expressions of the form " *
                (object_on_rhs ? "`a, b, ... = x`" : "`x = a, b, ...`"),
            ),
        )
    end

    # Extract the object
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
    if length(names) == 1
        p = first(names)
        expr = Expr(:call, fsym, esc(instance), QuoteNode(p), esc(p))
    else
        expr = Expr(:tuple)
        for p in names
            push!(expr.args, Expr(:call, fsym, esc(instance), QuoteNode(p), esc(p)))
        end
    end
    return Base.remove_linenums!(
        quote
            local $(esc(instance)) = $(esc(object)) # In case the object is an expression
            $expr
        end,
    )
end

end # module
