"""
    NodeSet(nodes)

Set of interpolation nodes.
"""
mutable struct NodeSet{Dim, RealT}
    nodes::Vector{MVector{Dim, RealT}}
    q::Float64
end

function Base.show(io::IO, nodeset::NodeSet)
    print(io, "NodeSet{", dim(nodeset), ", ", eltype(nodeset),
          "} with separation distance q = ", nodeset.q, " and ", length(nodeset), " nodes")
end

function Base.show(io::IO, ::MIME"text/plain", nodeset::NodeSet)
    if get(io, :compact, false)
        show(io, semi)
    else
        println(io, "NodeSet{", dim(nodeset), ", ", eltype(nodeset), "} with ",
                "separation distance q = ", nodeset.q, " and ", length(nodeset), " nodes:")
        max_nodes = 20
        for i in 1:min(max_nodes, length(nodeset))
            if isassigned(nodeset, i)
                println(io, "  ", nodeset[i])
            else
                println(io, "  ", "#undef")
            end
        end
        if length(nodeset) > max_nodes
            println("  ⋮")
        end
    end
end

# Constructors
function NodeSet(nodes::Vector{MVector{Dim, RealT}}) where {Dim, RealT}
    q = separation_distance(nodes)
    NodeSet{Dim, RealT}(nodes, q)
end
function NodeSet(nodes::AbstractVector{Vector{RealT}}) where {RealT}
    n = length(nodes)
    @assert n > 0
    ndims = length(nodes[1])
    @assert ndims > 0
    data = [MVector{ndims, RealT}(nodes[i]) for i in 1:n]
    return NodeSet(data)
end
function NodeSet(nodes::AbstractMatrix{RealT}) where {RealT}
    NodeSet(Vector{eltype(nodes)}[eachrow(nodes)...])
end
function NodeSet(nodes::AbstractVector{RealT}) where {RealT}
    @assert length(nodes) > 0
    return NodeSet([[node] for node in nodes])
end

function separation_distance(nodes::Vector{MVector{Dim, RealT}}) where {Dim, RealT}
    r = Inf
    for (i, x) in enumerate(nodes)
        for (j, y) in enumerate(nodes)
            if i != j && norm(x - y) < r
                r = norm(x - y)
            end
        end
    end
    return 0.5 * r
end

@doc raw"""
    separation_distance(nodeset::NodeSet)

Return the separation distance of a node set ``X = \{x_1,\ldots, x_n\}`` defined by
```math
    q_X = \frac{1}{2}\min_{x_i\neq x_j}\|x_i - x_j\|.
```
"""
separation_distance(nodeset::NodeSet) = nodeset.q
function update_separation_distance!(nodeset::NodeSet)
    # Update separation distance only if all values are assigned to prevent `UndefRefError`
    if all(map(i -> isassigned(nodeset, i), 1:length(nodeset)))
        q = separation_distance(nodeset.nodes)
        nodeset.q = q
    end
end
dim(nodeset::NodeSet{Dim, RealT}) where {Dim, RealT} = Dim
# Functions to treat NodeSet as array
Base.eltype(nodeset::NodeSet{Dim, RealT}) where {Dim, RealT} = RealT
Base.length(nodeset::NodeSet) = length(nodeset.nodes)
Base.size(nodeset::NodeSet) = (length(nodeset), dim(nodeset))
Base.iterate(nodeset::NodeSet, state = 1) = iterate(nodeset.nodes, state)
Base.collect(nodeset::NodeSet) = collect(nodeset.nodes)
Base.axes(nodeset::NodeSet) = axes(nodeset.nodes)
Base.isassigned(nodeset::NodeSet, i::Int) = isassigned(nodeset.nodes, i)
function Base.similar(nodeset::NodeSet{Dim, RealT}) where {Dim, RealT}
    NodeSet{Dim, RealT}(similar(nodeset.nodes), Inf)
end
function Base.similar(nodeset::NodeSet{Dim, RealT}, ::Type{T}) where {Dim, RealT, T}
    NodeSet{Dim, T}(similar(nodeset.nodes, MVector{Dim, T}), Inf)
end
function Base.similar(nodeset::NodeSet{Dim, RealT}, n::Int) where {Dim, RealT}
    NodeSet{Dim, RealT}(similar(nodeset.nodes, n), Inf)
end
function Base.similar(nodeset::NodeSet{Dim, RealT}, ::Type{T}, n::Int) where {Dim, RealT, T}
    NodeSet{Dim, T}(similar(nodeset.nodes, MVector{Dim, T}, n), Inf)
end
Base.getindex(nodeset::NodeSet, i::Int) = getindex(nodeset.nodes, i)
Base.getindex(nodeset::NodeSet, is::UnitRange) = nodeset.nodes[is]
Base.lastindex(nodeset::NodeSet) = lastindex(nodeset.nodes)
function Base.setindex!(nodeset::NodeSet{Dim, RealT}, v::MVector{Dim, RealT},
                        i::Int) where {Dim, RealT}
    nodeset.nodes[i] = v
end
function Base.setindex!(nodeset::NodeSet{Dim, RealT}, v::Vector{RealT},
                        i::Int) where {Dim, RealT}
    @assert length(v) == dim(nodeset)
    nodeset.nodes[i] = v
    # update separation distance of nodeset because it possibly changed
    # could be done more efficiently
    update_separation_distance!(nodeset)
end
function Base.setindex!(nodeset::NodeSet{1, RealT}, v::RealT, i::Int) where {RealT}
    @assert dim(nodeset) == 1
    nodeset.nodes[i] = [v]
    # update separation distance of nodeset because it possibly changed
    # could be done more efficiently
    update_separation_distance!(nodeset)
end
function Base.push!(nodeset::NodeSet{Dim, RealT}, v::MVector{Dim, RealT}) where {Dim, RealT}
    push!(nodeset.nodes, v)
    # update separation distance of nodeset because it possibly changed
    # could be done more efficiently
    update_separation_distance!(nodeset)
end
function Base.push!(nodeset::NodeSet{Dim, RealT}, v::Vector{RealT}) where {Dim, RealT}
    @assert length(v) == dim(nodeset)
    push!(nodeset.nodes, v)
    # update separation distance of nodeset because it possibly changed
    # could be done more efficiently
    update_separation_distance!(nodeset)
end
function Base.pop!(nodeset::NodeSet)
    pop!(nodeset.nodes)
    # update separation distance of nodeset because it possibly changed
    # could be done more efficiently
    update_separation_distance!(nodeset)
end
function Base.merge(nodeset::NodeSet{Dim, RealT},
                    others::NodeSet{Dim, RealT}...) where {Dim, RealT}
    nodes_merged = similar(nodeset, 0)
    merge!(nodes_merged, nodeset, others...)
    return nodes_merged
end
function Base.merge!(nodeset::NodeSet{Dim, RealT},
                     others::NodeSet{Dim, RealT}...) where {Dim, RealT}
    foreach(other -> append!(nodeset.nodes, other.nodes), others)
    update_separation_distance!(nodeset)
    #     return NodeSet(merge(nodeset.nodes, foreach(other -> other.nodes, others)...))
end
Base.unique(nodeset::NodeSet) = NodeSet(unique(nodeset.nodes))
function Base.unique!(nodeset::NodeSet)
    unique!(nodeset.nodes)
    update_separation_distance!(nodeset)
end
function Base.deleteat!(nodeset::NodeSet, i)
    deleteat!(nodeset.nodes, i)
    update_separation_distance!(nodeset)
end

"""
    values_along_dim(nodeset::NodeSet, i::Int)

Convenience function to return all ``x_i``-values of the nodes, i.e. the `i`-th component of each node.
Supported for `nodeset` with `dim(nodeset) >= i`.
"""
function values_along_dim(nodeset::NodeSet, i::Int)
    @assert dim(nodeset) >= i
    x_i = Vector{eltype(nodeset)}(undef, length(nodeset))
    for (j, node) in enumerate(nodeset)
        x_i[j] = node[i]
    end
    return x_i
end

# Some convenience function to create some specific `NodeSet`s
"""
    random_hypercube(n, dim, x_min = ntuple(_ -> 0.0, dim), x_max = ntuple(_ -> 1.0, dim))

Create a `NodeSet` with `n` random nodes each of dimension `dim` inside a hypercube defined by
the bounds `x_min` and `x_max`. If the bounds are given as single values, they are applied for
each dimension. If they are `Tuple`s of size `dim` the hypercube has the according bounds.
"""
function random_hypercube(n::Int, dim::Int, x_min, x_max)
    nodes = x_min .+ (x_max - x_min) .* rand(n, dim)
    return NodeSet(nodes)
end

function random_hypercube(n::Int, dim::Int, x_min::NTuple{Dim} = ntuple(_ -> 0.0, dim),
                          x_max::NTuple{Dim} = ntuple(_ -> 1.0, dim)) where {Dim}
    @assert dim == Dim
    nodes = rand(n, dim)
    for i in 1:dim
        nodes[:, i] = x_min[i] .+ (x_max[i] - x_min[i]) .* view(nodes, :, i)
    end
    return NodeSet(nodes)
end

"""
    random_hypercube_boundary(n, dim, x_min = ntuple(_ -> 0.0, dim), x_max = ntuple(_ -> 1.0, dim))

Create a `NodeSet` with `n` random nodes each of dimension `dim` on the boundary of a hypercube
defined by the bounds `x_min` and `x_max`. If the bounds are given as single values, they are
applied for each dimension. If they are `Tuple`s of size `dim` the hypercube has the according bounds.
"""
function random_hypercube_boundary(n::Int, dim::Int, x_min, x_max)
    random_hypercube_boundary(n, dim, ntuple(_ -> x_min, dim), ntuple(_ -> x_max, dim))
end

function project_on_hypercube_boundary!(nodeset::NodeSet{Dim}, x_min::NTuple{Dim},
                                        x_max::NTuple{Dim}) where {Dim}
    for i in 1:length(nodeset)
        #         j = argmin([abs.(nodeset[i] .- x_min); abs.(nodeset[i] .- x_max)])
        # Project to random axis
        j = rand(1:Dim)
        if rand([1, 2]) == 1
            nodeset[i][j] = x_min[j]
        else
            nodeset[i][j] = x_max[j]
        end
    end
end

function random_hypercube_boundary(n::Int, dim::Int,
                                   x_min::NTuple{Dim} = ntuple(_ -> 0.0, dim),
                                   x_max::NTuple{Dim} = ntuple(_ -> 1.0, dim)) where {Dim}
    @assert dim == Dim
    if dim == 1 && n >= 2
        @warn "For one dimension the boundary of the hypercube consists only of 2 points"
        return NodeSet([x_min[1], x_max[1]])
    end
    # First, create random nodes *inside* hypercube
    nodeset = random_hypercube(n, dim, x_min, x_max)
    # Then, project all the nodes on the boundary
    project_on_hypercube_boundary!(nodeset, x_min, x_max)
    return nodeset
end

"""
    homogeneous_hypercube(n, dim, x_min = ntuple(_ -> 0.0, dim), x_max = ntuple(_ -> 1.0, dim))

Create a `NodeSet` with `n` homogeneously distributed nodes in every dimension each of dimension
`dim` inside a hypercube defined by the bounds `x_min` and `x_max`. The resulting `NodeSet` will have
``n^{\textrm{dim}}`` points. If the bounds are given as single values, they are applied for each dimension.
If they are `Tuple`s of size `dim` the hypercube has the according bounds.
"""
function homogeneous_hypercube(n::Int, dim::Int, x_min, x_max)
    return homogeneous_hypercube(n, dim, ntuple(_ -> x_min, dim), ntuple(_ -> x_max, dim))
end

function homogeneous_hypercube(n::Int, dim::Int, x_min::NTuple{Dim} = ntuple(_ -> 0.0, dim),
                               x_max::NTuple{Dim} = ntuple(_ -> 1.0, dim)) where {Dim}
    @assert dim == Dim
    nodes = Vector{MVector{dim, Float64}}(undef, n^dim)
    for (i, indices) in enumerate(Iterators.product(ntuple(_ -> 1:n, dim)...))
        node = Vector(undef, dim)
        for j in 1:dim
            node[j] = x_min[j] + (x_max[j] - x_min[j]) * (indices[j] - 1) / (n - 1)
        end
        nodes[i] = node
    end
    return NodeSet(nodes)
end

"""
    homogeneous_hypercube_boundary(n, dim, x_min = ntuple(_ -> 0.0, dim), x_max = ntuple(_ -> 1.0, dim))

Create a `NodeSet` with `n` homogeneously distributed nodes in every dimension each of dimension
`dim` on the boundary of a hypercube defined by the bounds `x_min` and `x_max`. If the bounds are
given as single values, they are applied for each dimension. If they are `Tuple`s of size `dim`
the hypercube has the according bounds.
"""
function homogeneous_hypercube_boundary(n::Int, dim::Int, x_min, x_max)
    homogeneous_hypercube_boundary(n, dim, ntuple(_ -> x_min, dim), ntuple(_ -> x_max, dim))
end

# Total number of nodes of on a hypercube of dimension `dim` with `n` nodes in each direction
function number_of_nodes(n, dim)
    if dim == 1
        return 2
    end
    return 2 * n^(dim - 1) + (n - 2) * number_of_nodes(n, dim - 1)
end

# TODO: Is there a better way to create these `NodeSet`s?
function homogeneous_hypercube_boundary(n::Int, dim::Int,
                                        x_min::NTuple{Dim} = ntuple(_ -> 0.0, dim),
                                        x_max::NTuple{Dim} = ntuple(_ -> 1.0, dim)) where {
                                                                                           Dim
                                                                                           }
    if dim == 1 && n >= 2
        #         @warn "For one dimension the boundary of the hypercube consists only of 2 points"
        return NodeSet([x_min[1], x_max[1]])
    end
    @assert dim == Dim
    nodes = Vector{MVector{dim, Float64}}(undef, number_of_nodes(n, dim))
    local i = 1
    # Left side is like homogeneous hypercube in `dim - 1` hypercube
    for indices in Iterators.product(ntuple(_ -> 1:n, dim - 1)...)
        node = Vector(undef, dim)
        node[1] = x_min[1]
        for j in 2:dim
            node[j] = x_min[j] + (x_max[j] - x_min[j]) * (indices[j - 1] - 1) / (n - 1)
        end
        nodes[i] = node
        i += 1
    end

    # Sides in between by recursion
    for j in 2:(n - 1)
        nodeset2 = homogeneous_hypercube_boundary(n, dim - 1, x_min[2:end], x_max[2:end])
        for node in nodeset2
            nodes[i] = [x_min[1] + (x_max[1] - x_min[1]) * (j - 1) / (n - 1); node]
            i += 1
        end
    end

    # Right side is like homogeneous hypercube in `dim - 1` hypercube
    for indices in Iterators.product(ntuple(_ -> 1:n, dim - 1)...)
        node = Vector(undef, dim)
        node[1] = x_max[1]
        for j in 2:dim
            node[j] = x_min[j] + (x_max[j] - x_min[j]) * (indices[j - 1] - 1) / (n - 1)
        end
        nodes[i] = node
        i += 1
    end
    return NodeSet(nodes)
end

"""
    random_hypersphere(n, dim, r = 1.0, center = zeros(dim))

Create a `NodeSet` with `n` random nodes each of dimension `dim` inside a hypersphere with
radius `r` around the center `center`.
"""
function random_hypersphere(n::Int, dim::Int, r = 1.0, center = zeros(dim))
    nodes = randn(n, dim)
    for i in 1:n
        nodes[i, :] .= center .+ r .* nodes[i, :] ./ norm(nodes[i, :]) * rand()^(1 / dim)
    end
    return NodeSet(nodes)
end

"""
    random_hypersphere_boundary(n, dim, r = 1.0, center = zeros(dim))

Create a `NodeSet` with `n` random nodes each of dimension `dim` at the boundary of a
hypersphere with radius `r` around the center `center`.
"""
function random_hypersphere_boundary(n::Int, dim::Int, r = 1.0, center = zeros(dim))
    if dim == 1 && n >= 2
        @warn "For one dimension the boundary of the hypersphere consists only of 2 points"
        return NodeSet([-r, r])
    end
    nodes = randn(n, dim)
    for i in 1:n
        nodes[i, :] .= center .+ r .* nodes[i, :] ./ norm(nodes[i, :])
    end
    return NodeSet(nodes)
end
