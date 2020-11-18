"""
Convert an array of tuples to a 2D array.
"""
# could restrict to number types, but allowing all types for now
#function array_from_tuples(T::Array{Tuple{Vararg{T,N}},1} where {T<:Number,N})
function array_from_tuples(arrtup::Array{Tuple{Vararg{T,N}},1} where {T,N})
    m = length(arrtup)
    n = length(arrtup[1])
    typename = typeof(arrtup[1][1])
    A = Array{typename}(undef, (m,n))
    for i in 1:m
        for j in 1:n
            A[i,j] = arrtup[i][j]
        end
    end
    return A
end
##
