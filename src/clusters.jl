using LinearAlgebra
using Random
#using Distributions
using Statistics

## Helper functions

""" Sterling number: number of partitions of a set of n elements in k sets """
sterling(n::BigInt,k::BigInt) = (1/factorial(k)) * sum((-1)^i * binomial(k,i)* (k-i)^n for i in 0:k)
sterling(n::Int64,k::Int64) = sterling(BigInt(n),BigInt(k))

# Some common distances
"""L1 norm distance (aka "Manhattan Distance")"""
l1_distance(x,y) = sum(abs.(x-y))

"""Euclidean (L2) distance"""
l2_distance(x,y) = norm(x-y)

"""Squared Euclidean (L2) distance"""
l2²_distance(x,y) = norm(x-y)^2

"""Cosine distance"""
cosine_distance(x,y) = dot(x,y)/(norm(x)*norm(y))

"""Transform an Array{T,1} in an Array{T,2} and leave unchanged Array{T,2}."""
make_matrix(x::Array) = ndims(x) == 1 ? reshape(x, (size(x)...,1)) : x

""" PDF of a multidimensional normal with no covariance and shared variance across dimensions"""
normalFixedSd(x,μ,σ²) = (1/(2π*σ²)^(length(x)/2)) * exp(-1/(2σ²)*norm(x-μ)^2)

""" log-PDF of a multidimensional normal with no covariance and shared variance across dimensions"""
logNormalFixedSd(x,μ,σ²) = - (length(x)/2) * log(2π*σ²)  -  norm(x-μ)^2/(2σ²)

""" LogSumExp for efficiently computing log(sum(exp.(x))) """
myLSE(x) = maximum(x)+log(sum(exp.(x .- maximum(x))))

"""
  initRepresentatives(X,K;initStrategy,Z₀))

Initialisate the representatives for a K-Mean or K-Medoids algorithm

# Parameters:
* `X`: a (N x D) data to clusterise
* `K`: Number of cluster wonted
* `initStrategy`: Wheter to select the initial representative vectors:
  * `random`: randomly in the X space
  * `grid`: using a grid approach [default]
  * `shuffle`: selecting randomly within the available points
  * `given`: using a provided set of initial representatives provided in the `Z₀` parameter
 * `Z₀`: Provided (K x D) matrix of initial representatives (used only together with the `given` initStrategy) [default: `nothing`]

# Returns:
* A (K x D) matrix of initial representatives

# Example:
```julia
julia> Z₀ = initRepresentatives([1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.6 38],2,initStrategy="given",Z₀=[1.7 15; 3.6 40])
```
"""
function initRepresentatives(X,K;initStrategy="grid",Z₀=nothing)
    X  = make_matrix(X)
    (N,D) = size(X)
    # Random choice of initial representative vectors (any point, not just in X!)
    minX = minimum(X,dims=1)
    maxX = maximum(X,dims=1)
    Z = zeros(K,D)
    if initStrategy == "random"
        for i in 1:K
            for j in 1:D
                Z[i,j] = rand(Uniform(minX[j],maxX[j]))
            end
        end
    elseif initStrategy == "grid"
        for d in 1:D
                Z[:,d] = collect(range(minX[d], stop=maxX[d], length=K))
        end
    elseif initStrategy == "given"
        if isnothing(Z₀) error("With the `given` strategy you need to provide the initial set of representatives in the Z₀ parameter.") end
        Z₀ = make_matrix(Z₀)
        Z = Z₀
    elseif initStrategy == "shuffle"
        zIdx = shuffle(1:size(X)[1])[1:K]
        Z = X[zIdx, :]
    else
        error("initStrategy \"$initStrategy\" not implemented")
    end
    return Z
end


## Basic K-Means Algorithm (Lecture/segment 13.7 of https://www.edx.org/course/machine-learning-with-python-from-linear-models-to)

"""
  kmeans(X,K;dist,initStrategy,Z₀)

Compute K-Mean algorithm to identify K clusters of X using Euclidean distance

# Parameters:
* `X`: a (N x D) data to clusterise
* `K`: Number of cluster wonted
* `dist`: Function to employ as distance (see notes). Default to Euclidean distance.
* `initStrategy`: Wheter to select the initial representative vectors:
  * `random`: randomly in the X space
  * `grid`: using a grid approach [default]
  * `shuffle`: selecting randomly within the available points
  * `given`: using a provided set of initial representatives provided in the `Z₀` parameter
* `Z₀`: Provided (K x D) matrix of initial representatives (used only together with the `given` initStrategy) [default: `nothing`]

# Returns:
* A tuple of two items, the first one being a vector of size N of ids of the clusters associated to each point and the second one the (K x D) matrix of representatives

# Notes:
* Some returned clusters could be empty
* The `dist` parameter can be:
  * Any user defined function accepting two vectors and returning a scalar
  * An anonymous function with the same characteristics (e.g. `dist = (x,y) -> norm(x-y)^2`)
  * One of the above predefined distances: `l1_distance`, `l2_distance`, `l2²_distance`, `cosine_distance`

# Example:
```julia
julia> (clIdx,Z) = kmeans([1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.3 38; 5.1 -2.3; 5.2 -2.4],3)
```
"""
function kmeans(X,K;dist=(x,y) -> norm(x-y),initStrategy="grid",Z₀=nothing)
    X  = make_matrix(X)
    (N,D) = size(X)
    # Random choice of initial representative vectors (any point, not just in X!)
    minX = minimum(X,dims=1)
    maxX = maximum(X,dims=1)
    Z₀ = initRepresentatives(X,K,initStrategy=initStrategy,Z₀=Z₀)
    Z  = Z₀
    cIdx_prev = zeros(Int64,N)

    # Looping
    while true
        # Determining the constituency of each cluster
        cIdx      = zeros(Int64,N)
        for (i,x) in enumerate(eachrow(X))
            cost = Inf
            for (j,z) in enumerate(eachrow(Z))
               if (dist(x,z)  < cost)
                   cost    =  dist(x,z)
                   cIdx[i] = j
               end
            end
        end

        # Determining the new representative by each cluster
        # for (j,z) in enumerate(eachrow(Z))
        for j in  1:K
            Cⱼ = X[cIdx .== j,:] # Selecting the constituency by boolean selection
            Z[j,:] = sum(Cⱼ,dims=1) ./ size(Cⱼ)[1]
            #Z[j,:] = median(Cⱼ,dims=1) # for l1 distance
        end

        # Checking termination condition: clusters didn't move any more
        if cIdx == cIdx_prev
            return (cIdx,Z)
        else
            cIdx_prev = cIdx
        end

    end
end

## Basic K-Medoids Algorithm (Lecture/segment 14.3 of https://www.edx.org/course/machine-learning-with-python-from-linear-models-to)
"""
  kmedoids(X,K;dist,initStrategy,Z₀)

Compute K-Medoids algorithm to identify K clusters of X using distance definition `dist`

# Parameters:
* `X`: a (n x d) data to clusterise
* `K`: Number of cluster wonted
* `dist`: Function to employ as distance (see notes). Default to Euclidean distance.
* `initStrategy`: Wheter to select the initial representative vectors:
  * `random`: randomly in the X space
  * `grid`: using a grid approach
  * `shuffle`: selecting randomly within the available points [default]
  * `given`: using a provided set of initial representatives provided in the `Z₀` parameter
 * `Z₀`: Provided (K x D) matrix of initial representatives (used only together with the `given` initStrategy) [default: `nothing`]

# Returns:
* A tuple of two items, the first one being a vector of size N of ids of the clusters associated to each point and the second one the (K x D) matrix of representatives

# Notes:
* Some returned clusters could be empty
* The `dist` parameter can be:
  * Any user defined function accepting two vectors and returning a scalar
  * An anonymous function with the same characteristics (e.g. `dist = (x,y) -> norm(x-y)^2`)
  * One of the above predefined distances: `l1_distance`, `l2_distance`, `l2²_distance`, `cosine_distance`

# Example:
```julia
julia> (clIdx,Z) = kmedoids([1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.3 38; 5.1 -2.3; 5.2 -2.4],3,initStrategy="grid")
```
"""
function kmedoids(X,K;dist=(x,y) -> norm(x-y),initStrategy="shuffle",Z₀=nothing)
    X  = make_matrix(X)
    (n,d) = size(X)
    # Random choice of initial representative vectors
    Z₀ = initRepresentatives(X,K,initStrategy=initStrategy,Z₀=Z₀)
    Z = Z₀
    cIdx_prev = zeros(Int64,n)

    # Looping
    while true
        # Determining the constituency of each cluster
        cIdx      = zeros(Int64,n)
        for (i,x) in enumerate(eachrow(X))
            cost = Inf
            for (j,z) in enumerate(eachrow(Z))
               if (dist(x,z) < cost)
                   cost =  dist(x,z)
                   cIdx[i] = j
               end
            end
        end

        # Determining the new representative by each cluster (within the points member)
        #for (j,z) in enumerate(eachrow(Z))
        for j in  1:K
            Cⱼ = X[cIdx .== j,:] # Selecting the constituency by boolean selection
            nⱼ = size(Cⱼ)[1]     # Size of the cluster
            if nⱼ == 0 continue end # empty continuency. Let's not do anything. Stil in the next batch other representatives could move away and points could enter this cluster
            bestCost = Inf
            bestCIdx = 0
            for cIdx in 1:nⱼ      # candidate index
                 candidateCost = 0.0
                 for tIdx in 1:nⱼ # target index
                     candidateCost += dist(Cⱼ[cIdx,:],Cⱼ[tIdx,:])
                 end
                 if candidateCost < bestCost
                     bestCost = candidateCost
                     bestCIdx = cIdx
                 end
            end
            Z[j,:] = reshape(Cⱼ[bestCIdx,:],1,d)
        end

        # Checking termination condition: clusters didn't move any more
        if cIdx == cIdx_prev
            return (cIdx,Z)
        else
            cIdx_prev = cIdx
        end
    end

end


## The EM algorithm (Lecture/segment 16.5 of https://www.edx.org/course/machine-learning-with-python-from-linear-models-to)

"""
  em(X,K;p₀,μ₀,σ²₀,tol,msgStep,minVariance,missingValue)

Compute Expectation-Maximisation algorithm to identify K clusters of X data assuming a Gaussian Mixture probabilistic Model.

X can contain missing values in some or all of its dimensions. In such case the learning is done only with the available data.
Implemented in the log-domain for better numerical accuracy with many dimensions.

# Parameters:
* `X`  :          A (n x d) data to clusterise
* `K`  :          Number of cluster wanted
* `p₀` :          Initial probabilities of the categorical distribution (K x 1) [default: `nothing`]
* `μ₀` :          Initial means (K x d) of the Gaussian [default: `nothing`]
* `σ²₀`:          Initial variance of the gaussian (K x 1). We assume here that the gaussian has the same variance across all the dimensions [default: `nothing`]
* `tol`:          Tolerance to stop the algorithm [default: 10^(-6)]
* `msgStep` :     Iterations between update messages. Use 0 for no updates [default: 10]
* `minVariance`:  Minimum variance for the mixtures [default: 0.25]
* `missingValue`: Value to be considered as missing in the X [default: 0]`

# Returns:
* A named touple of:
  * `pⱼₓ`: Matrix of size (N x K) of the probabilities of each point i to belong to cluster j
  * `pⱼ` : Probabilities of the categorical distribution (K x 1)
  * `μ`  : Means (K x d) of the Gaussian
  * `σ²` : Variance of the gaussian (K x 1). We assume here that the gaussian has the same variance across all the dimensions
  * `ϵ`  : Vector of the discrepancy (matrix norm) between pⱼₓ and the lagged pⱼₓ at each iteration

# Example:
```julia
julia> clusters = em([1 10.5;1.5 0; 1.8 8; 1.7 15; 3.2 40; 0 0; 3.3 38; 0 -2.3; 5.2 -2.4],3,msgStep=1,missingValue=0)
```
"""
function em(X,K;p₀=nothing,μ₀=nothing,σ²₀=nothing,tol=10^(-6),msgStep=10,minVariance=0.25,missingValue=missing)
    # debug:
    #X = [1 10.5;1.5 0; 1.8 8; 1.7 15; 3.2 40; 0 0; 3.3 38; 0 -2.3; 5.2 -2.4]
    #K = 3
    #p₀=nothing; μ₀=nothing; σ²₀=nothing; tol=0.0001; msgStep=1; minVariance=0.25; missingValue = 0

    X     = make_matrix(X)
    (N,D) = size(X)

    # Initialisation of the parameters if not provided
    minX = fill(-Inf,D)
    maxX = fill(Inf,D)
    varX_byD = fill(0,D)
    for d in 1:D
      minX[d]  = minimum(skipmissing(X[:,d]))
      maxX[d]  = maximum(skipmissing(X[:,d]))
      varX_byD = max(minVariance, var(skipmissing(X[:,d])))
    end
    varX = mean(varX_byD)/K^2

    pⱼ = isnothing(p₀) ? fill(1/K,K) : p₀
    if !isnothing(μ₀)
        μ₀  = make_matrix(μ₀)
        μ = μ₀
    else
        μ = zeros(Float64,K,D)
        for d in 1:D
                μ[:,d] = collect(range(minX[d], stop=maxX[d], length=K))
        end
    end
    σ² = isnothing(σ²₀) ? fill(varX,K) : σ²₀
    pⱼₓ = zeros(Float64,N,K) # The posteriors, i.e. the prob that item n belong to cluster k
    ϵ = Float64[]

    # finding empty/non_empty values
    XMask = ismissing(missingValue) ?  .! ismissing.(X)  : (X .!= missingValue)
    XdimCount = sum(XMask, dims=2)

    lL = -Inf

    while(true)
        oldlL = lL
        # E Step: assigning the posterior prob p(j|xi) and computing the log-Likelihood of the parameters given the set of data
        # (this last one for informative purposes and terminating the algorithm)
        pⱼₓlagged = copy(pⱼₓ)
        logpⱼₓ = log.(pⱼₓ)
        lL = 0
        for n in 1:N
            if any(XMask[n,:]) # if at least one true
                Xu = X[n,XMask[n,:]]
                logpx = myLSE([log(pⱼ[k] + 1e-16) + logNormalFixedSd(Xu,μ[k,XMask[n,:]],σ²[k]) for k in 1:K])
                lL += logpx
                #px = sum([pⱼ[k]*normalFixedSd(Xu,μ[k,XMask[n,:]],σ²[k]) for k in 1:K])
                for k in 1:K
                    logpⱼₓ[n,k] = log(pⱼ[k] + 1e-16)+logNormalFixedSd(Xu,μ[k,XMask[n,:]],σ²[k])-logpx
                end
            else
                logpⱼₓ[n,:] = log.(pⱼ)
            end
        end
        pⱼₓ = exp.(logpⱼₓ)

        push!(ϵ,norm(pⱼₓlagged - pⱼₓ))

        # M step: find parameters that maximise the likelihood
        nⱼ = sum(pⱼₓ,dims=1)'
        n  = sum(nⱼ)
        pⱼ = nⱼ ./ n

        #μ  = (pⱼₓ' * X) ./ nⱼ
        for d in 1:D
            for k in 1:K
                nᵢⱼ = sum(pⱼₓ[XMask[:,d],k])
                if nᵢⱼ > 1
                    μ[k,d] = sum(pⱼₓ[XMask[:,d],k] .* X[XMask[:,d],d])/nᵢⱼ
                end
            end
        end

        #σ² = [sum([pⱼₓ[n,j] * norm(X[n,:]-μ[j,:])^2 for n in 1:N]) for j in 1:K ] ./ (nⱼ .* D)
        for k in 1:K
            den = dot(XdimCount,pⱼₓ[:,k])
            nom = 0.0
            for n in 1:N
                if any(XMask[n,:])
                    nom += pⱼₓ[n,k] * norm(X[n,XMask[n,:]]-μ[k,XMask[n,:]])^2
                end
            end
            if(den> 0 && (nom/den) > minVariance)
                σ²[k] = nom/den
            else
                σ²[k] = minVariance
            end
        end

        # Information. Note the likelihood is whitout accounting for the new mu, sigma
        if msgStep != 0 && (length(ϵ) % msgStep == 0 || length(ϵ) == 1)
            println("Iter. $(length(ϵ)):\tVariation of the posteriors  $(ϵ[end]) \t  Log-likelihood $(lL)")
        end

        # Closing conditions. Note that the logLikelihood is those without considering the new mu,sigma
        if (lL - oldlL) <= (tol * abs(lL))
        #if (ϵ[end] < tol)
           return (pⱼₓ=pⱼₓ,pⱼ=pⱼ,μ=μ,σ²=σ²,ϵ=ϵ,lL=lL)
        end
    end # end while loop
end # end function

#using BenchmarkTools
#@benchmark clusters = em([1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.3 38; 5.1 -2.3; 5.2 -2.4],3,msgStep=0)
#@benchmark clusters = em([1 10.5;1.5 0; 1.8 8; 1.7 15; 3.2 40; 0 0; 3.3 38; 0 -2.3; 5.2 -2.4],3,msgStep=0,missingValue=0)
#@benchmark clusters = em([1 10.5;1.5 0; 1.8 8; 1.7 15; 3.2 40; 0 0; 3.3 38; 0 -2.3; 5.2 -2.4],3,msgStep=0,missingValue=0)
#@benchmark clusters = em([1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4],3,msgStep=0)
#@code_warntype em([1 10.5;1.5 0; 1.8 8; 1.7 15; 3.2 40; 0 0; 3.3 38; 0 -2.3; 5.2 -2.4],3,msgStep=0,missingValue=0)
