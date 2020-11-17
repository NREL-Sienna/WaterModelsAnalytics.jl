"""
Convert an array of tuples to a 2D array. Presumes that the tuples are all the same
length and type (there is currently no check).
"""
# can't figure out how to pre-set the type!
#function array_from_tuples(T::Array{Tuple{Vararg{Number},1})
function array_from_tuples(T) 
    m = length(T)
    n = length(T[1])
    typename = typeof(T[1][1])
    A = Array{typename}(undef, (m,n))
    for i in 1:m
        for j in 1:n
            A[i,j] = T[i][j]
        end
    end
    return A
end
##
