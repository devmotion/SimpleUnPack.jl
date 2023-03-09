"""
    split_names_object(macrosym::Symbol, expr; object_on_rhs::Bool)

Split an expression `expr` of the form `a, b, ... = x` (if `object_on_rhs = true`) or `x = a, b, ...` (if `object_on_rhs = false`) into a tuple consisting of a vector of symbols `a`, `b`, ..., and the expression or symbol for `x`.

The symbol `macro_name` specifies the macro from which this function is called.

This function is used internally with `macrosym = :unpack`, `macrosym = :unpack_fields`, `macrosym = :pack!`, and `macrosym = :pack_fields!`.
"""
function split_names_object(macrosym::Symbol, expr; object_on_rhs::Bool)
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
