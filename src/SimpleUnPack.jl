module SimpleUnPack

export @unpack

"""
    @unpack a, b, ... = x

Destructure properties `a`, `b`, ... of `x` into variables of the same name.

The behaviour of the macro is equivalent to `(; a, b, ...) = x` which was introduced in [Julia#39285](https://github.com/JuliaLang/julia/pull/39285) and is available in Julia >= 1.7.0-DEV.364.
"""
macro unpack(args)
    return unpack(args)
end

function unpack(args)
    # Extract properties and RHS
    if !Meta.isexpr(args, :(=), 2)
        throw(
            ArgumentError(
                "`@unpack` can only be applied to expressions of the form `a, b, ... = x`"
            ),
        )
    end
    lhs, rhs = args.args
    properties = if lhs isa Symbol
        [lhs]
    elseif Meta.isexpr(lhs, :tuple) &&
        !isempty(lhs.args) &&
        all(x -> x isa Symbol, lhs.args)
        lhs.args
    else
        throw(
            ArgumentError(
                "`@unpack` can only be applied to expressions of the form `a, b, ... = x`",
            ),
        )
    end

    if VERSION >= v"1.7.0-DEV.364"
        # Fall back to destructuring in Base when available:
        # https://github.com/JuliaLang/julia/pull/39285
        return Expr(
            :(=), Expr(:tuple, Expr(:parameters, (esc(p) for p in properties)...)), esc(rhs)
        )
    else
        @gensym object
        block = Expr(:block)
        for p in properties
            push!(
                block.args,
                Expr(:(=), esc(p), Expr(:call, :getproperty, esc(object), QuoteNode(p))),
            )
        end
        return Base.remove_linenums!(
            quote
                $(esc(object)) = $(esc(rhs)) # In case the RHS is an expression
                $block
                $(esc(object)) # Return evaluation of rhs to ensure the behaviour is the same as (; ...) = rhs
            end,
        )
    end
end

end
