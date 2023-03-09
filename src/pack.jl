"""
    @pack! x = a, b, ...

Set properties `a`, `b`, ... of `x` to the given values.

See also [`@pack_fields!`](@ref), [`@unpack`](@ref), [`@unpack_fields`](@ref)
"""
macro pack!(args)
    # Extract names of properties and the object that will be updated
    names, object = split_names_object(:pack!, args; object_on_rhs=false)

    # Construct updating expression
    expr = updating_expr(:setproperty!, object, names)

    return expr
end

"""
    @pack_fields! x = a, b, ...

Set fields `a`, `b`, ... of `x` to the given values.

See also [`@pack!`](@ref), [`@unpack`](@ref), [`@unpack_fields`](@ref)
"""
macro pack_fields!(args)
    # Extract names of properties and the object that will be updated
    names, object = split_names_object(:pack_fields!, args; object_on_rhs=false)

    # Construct updating expression
    expr = updating_expr(:setfield!, object, names)

    return expr
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
