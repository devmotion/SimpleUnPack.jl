module SimpleUnPack

export @unpack, @unpack_fields, @pack!, @pack_fields!

include("common.jl")
include("pack.jl")
include("unpack.jl")

end # module
