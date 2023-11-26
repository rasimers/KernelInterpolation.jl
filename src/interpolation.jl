abstract type AbstractInterpolation{K, Dim, RealT} end

"""
    kernel(itp)

Return the kernel from an interpolation object.
"""
kernel(itp::AbstractInterpolation) = itp.k

"""
    nodeset(itp)

Return the node set from an interpolation object.
"""
nodeset(itp::AbstractInterpolation) = itp.nodeset

@doc raw"""
    Interpolation

Interpolation object that can be evaluated at a node and represents a kernel interpolation of the form
```math
    s(x) = \sum_{j = 1}^n c_jK(x, x_j) + \sum_{k = 1}^q d_kp_k(x),
```
where ``x_j`` are the nodes in the nodeset and ``s(x)`` the interpolant satisfying ``s(x_j) = f(x_j)``, where
``f(x_j)`` are given by `values` and ``p_k`` is a basis of the `q`-dimensional space of multivariate
polynomials with maximum degree of `polynomial_degree`. The additional conditions
```math
    \sum_{j = 1}^n c_jp_k(x_j) = 0, \quad k = 1,\ldots, q
```
are enforced.
"""
struct Interpolation{K, Dim, RealT, A, Monomials, PolyVars} <: AbstractInterpolation{K, Dim, RealT}
    k::K
    nodeset::NodeSet{Dim, RealT}
    c::Vector{RealT}
    factorized_system_matrix::A
    ps::Monomials
    xx::PolyVars
end

function Base.show(io::IO, itp::Interpolation)
    return print(io,
                 "Interpolation with $(length(nodeset(itp))) nodes, $(kernel(itp)) kernel and polynomial of order $(order(itp)).")
end

"""
    dim(itp::Interpolation)

Return the dimension of the input variables of the interpolation.
"""
dim(itp::Interpolation{K, Dim, RealT, A}) where {K, Dim, RealT, A} = Dim

"""
    coefficients(itp::Interpolation)

Obtain all the coefficients of the linear combination for the interpolant, i.e. both
the coefficients for the kernel part and for the polynomial part.

See also [`kernel_coefficients`](@ref) and [`polynomial_coefficients`](@ref).
"""
coefficients(itp::Interpolation) = itp.c

"""
    kernel_coefficients(itp::Interpolation)

Obtain the coefficients of the kernel part of the linear combination for the
interpolant.

See also [`coefficients`](@ref) and [`polynomial_coefficients`](@ref).
"""
kernel_coefficients(itp::Interpolation) = itp.c[1:length(nodeset(itp))]

"""
    polynomial_coefficients(itp::Interpolation)

Obtain the coefficients of the polynomial part of the linear combination for the
interpolant.

See also [`coefficients`](@ref) and [`kernel_coefficients`](@ref).
"""
polynomial_coefficients(itp::Interpolation) = itp.c[(length(nodeset(itp)) + 1):end]

"""
    polynomial_basis(itp::Interpolation)

Return a vector of the polynomial basis functions used for the interpolation.

See also [`polyvars`](@ref).
"""
polynomial_basis(itp::Interpolation) = itp.ps

"""
    polyvars(itp::Interpolation)

Return a vector of the polynomial variables.

See also [`polynomial_basis`](@ref).
"""
polyvars(itp::Interpolation) = itp.xx

"""
    order(itp)

Return the order ``m`` of the polynomial used for the interpolation, i.e.
the polynomial degree plus 1. If ``m = 0``, no polynomial is added.
"""
order(itp::Interpolation) = maximum(degree.(itp.ps), init = -1) + 1

@doc raw"""
    system_matrix(itp::Interpolation)

Return the system matrix, i.e. the matrix
```math
\begin{pmatrix}
A & P \\
P^T 0
\end{pmatrix},
```
where ``A\in\mathrm{R}^{n\times n}`` is the matrix with entries
``a_{ij} = K(x_i, x_j)`` for the kernel function `K` and nodes `x_i`
and ``P\in\mathrm{R}^{n\times q}`` is the matrix with entries
``p_{ij} = p_j(x_i)``, where ``p_j`` is the ``j``-th multivariate monomial
of the space of polynomials up to degree ``m``.
"""
system_matrix(itp::Interpolation) = itp.factorized_system_matrix

@doc raw"""
    interpolate(nodeset, values, k = GaussKernel{dim(nodeset)}(), m = order(k))

Interpolate the `values` evaluated at the nodes in the `nodeset` to a function using the kernel `k`
and polynomials up to a degree `polynomial_degree`, i.e. determine the coefficients `c_j` and `d_k` in the expansion
```math
    s(x) = \sum_{j = 1}^n c_jK(x, x_j) + \sum_{k = 1}^q d_kp_k(x),
```
where ``x_j`` are the nodes in the nodeset and ``s(x)`` the interpolant ``s(x_j) = f(x_j)``, where ``f(x_j)``
are given by `values` and ``p_k`` is a basis of the `q`-dimensional space of multivariate polynomials with
maximum degree of `m - 1`. If `m = 0`, no polynomial is added. The additional conditions
```math
    \sum_{j = 1}^n c_jp_k(x_j) = 0, \quad k = 1,\ldots, q
```
are enforced.
"""
function interpolate(nodeset::NodeSet{Dim, RealT}, values::Vector{RealT},
                     k = GaussKernel{dim(nodeset)}(), m = order(k)) where {Dim, RealT}
    @assert dim(k) == Dim
    n = length(nodeset)
    @assert length(values) == n
    xx = polyvars(Dim)
    ps = monomials(xx, 0:(m - 1))
    q = length(ps)

    kernel_matrix = Matrix{RealT}(undef, n, n)
    for i in 1:n
        for j in 1:n
            kernel_matrix[i, j] = k(nodeset[i], nodeset[j])
        end
    end
    polynomial_matrix = Matrix{RealT}(undef, n, q)
    for i in 1:n
        for j in 1:q
            polynomial_matrix[i, j] = ps[j](xx => nodeset[i])
        end
    end
    system_matrix = [kernel_matrix polynomial_matrix
                     transpose(polynomial_matrix) zeros(q, q)]
    b = [values; zeros(q)]
    factorized_system_matrix = factorize(system_matrix)
    c = factorized_system_matrix \ b
    return Interpolation(k, nodeset, c, factorized_system_matrix, ps, xx)
end

# Evaluate interpolant
function (itp::Interpolation)(x)
    s = 0
    k = kernel(itp)
    xs = nodeset(itp)
    c = kernel_coefficients(itp)
    d = polynomial_coefficients(itp)
    ps = polynomial_basis(itp)
    xx = polyvars(itp)
    for i in 1:length(c)
        s += c[i] * k(x, xs[i])
    end

    for j in 1:length(d)
        # Allow scalar input if interpolant is one-dimensional
        if x isa Real
            s += d[j] * ps[j](xx => [x])
        else
            s += d[j] * ps[j](xx => x)
        end
    end
    return s
end
