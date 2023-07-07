"Part of [BetaML](https://github.com/sylvaticus/BetaML.jl). Licence is MIT."

using Statistics, LinearAlgebra, PDMats
import Distributions: IsoNormal, DiagNormal, FullNormal, logpdf
import PDMats: ScalMat, PDiagMat, PDMat
import BetaML.Clustering: kmeans
export SphericalGaussian, DiagonalGaussian, FullGaussian,
       init_mixtures!,lpdf, update_parameters!

#export initVariances!, updateVariances!



abstract type AbstractGaussian <: AbstractMixture end

mutable struct SphericalGaussian{T <:Number} <: AbstractGaussian
        μ  ::Union{Array{T,1},Nothing}
        σ² ::Union{T,Nothing}
        #SphericalGaussian(;μ::Union{Array{T,1},Nothing},σ²::Union{T,Nothing}) where {T} = SphericalGaussian(μ,σ²)
        @doc """

        $(TYPEDSIGNATURES)

        SphericalGaussian(μ,σ²) - Spherical Gaussian mixture with mean μ and (single) variance σ²
        """
        SphericalGaussian(μ::Union{Array{T,1},Nothing},σ²::Union{T,Nothing}=nothing) where {T} = new{T}(μ,σ²)
        SphericalGaussian(type::Type{T}=Float64) where {T} = new{T}(nothing, nothing)
end

mutable struct DiagonalGaussian{T <:Number} <: AbstractGaussian
    μ::Union{Array{T,1},Nothing}
    σ²::Union{Array{T,1},Nothing}
    @doc """

    $(TYPEDSIGNATURES)
    
    DiagonalGaussian(μ,σ²) - Gaussian mixture with mean μ and variances σ² (and fixed zero covariances)
    """
    DiagonalGaussian(μ::Union{Array{T,1},Nothing},σ²::Union{Array{T,1},Nothing}=nothing) where {T} = new{T}(μ,σ²)
    DiagonalGaussian(::Type{T}=Float64) where {T} = new{T}(nothing, nothing)
end

mutable struct FullGaussian{T <:Number} <: AbstractGaussian
    μ::Union{Array{T,1},Nothing}
    σ²::Union{Array{T,2},Nothing}
    @doc """

    $(TYPEDSIGNATURES)
    
    FullGaussian(μ,σ²) - Gaussian mixture with mean μ and variance/covariance matrix σ²"""
    FullGaussian(μ::Union{Array{T,1},Nothing},σ²::Union{Array{T,2},Nothing}=nothing) where {T} = new{T}(μ,σ²)
    FullGaussian(::Type{T}=Float64) where {T} = new{T}(nothing, nothing)
end

function initVariances!(mixtures::Array{T,1}, X; minimum_variance=0.25, minimum_covariance=0.0,rng = Random.GLOBAL_RNG) where {T <: SphericalGaussian}
    (N,D)         = size(X)
    K             = length(mixtures)
    varX_byD      = fill(0.0,D)
    for d in 1:D
      varX_byD[d] = var(skipmissing(X[:,d]))
    end
    varX = max(minimum_variance,mean(varX_byD)/K^2)

    for (i,m) in enumerate(mixtures)
        if isnothing(m.σ²)
            m.σ² = varX
        end
    end
end

function initVariances!(mixtures::Array{T,1}, X; minimum_variance=0.25, minimum_covariance=0.0,rng = Random.GLOBAL_RNG) where {T <: DiagonalGaussian}
    (N,D)         = size(X)
    K             = length(mixtures)
    varX_byD      = fill(0.0,D)
    for d in 1:D
      varX_byD[d] = max(minimum_variance, var(skipmissing(X[:,d])))
    end

    for (i,m) in enumerate(mixtures)
        if isnothing(m.σ²)
            m.σ² = varX_byD
        end
    end

end

function initVariances!(mixtures::Array{T,1}, X; minimum_variance=0.25, minimum_covariance=0.0,rng = Random.GLOBAL_RNG) where {T <: FullGaussian}
    (N,D) = size(X)
    K = length(mixtures)
    varX_byD = fill(0.0,D)

    for d in 1:D
      varX_byD[d] = max(minimum_variance, var(skipmissing(X[:,d])))
    end

    for (i,m) in enumerate(mixtures)
        if isnothing(m.σ²)
            m.σ² = fill(0.0,D,D)
            for d1 in 1:D
                for d2 in 1:D
                    if d1 == d2
                        m.σ²[d1,d2] = varX_byD[d1]
                    else
                        m.σ²[d1,d2] = minimum_covariance
                    end
                end
            end
        end
    end
end


"""
    init_mixtures!(mixtures::Array{T,1}, X; minimum_variance=0.25, minimum_covariance=0.0, initialisation_strategy="grid",rng=Random.GLOBAL_RNG)


 The parameter `initialisation_strategy` can be `grid`, `kmeans` or `given`:
 - `grid`: Uniformly cover the space observed by the data
 - `kmeans`: Use the kmeans algorithm. If the data contains missing values, a first run of `predictMissing` is done under init=`grid` to impute the missing values just to allow the kmeans algorithm. Then the em algorithm is used with the output of kmean as init values.
 - `given`: Leave the provided set of initial mixtures

"""
function init_mixtures!(mixtures::Array{T,1}, X; minimum_variance=0.25, minimum_covariance=0.0, initialisation_strategy="grid",rng = Random.GLOBAL_RNG) where {T <: AbstractGaussian}
    # debug..
    #X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing 2; 3.3 38; missing -2.3; 5.2 -2.4]
    #mixtures = [SphericalGaussian() for i in 1:3]
    # ---
    if initialisation_strategy == "given"
        return
    end

    (N,D) = size(X)
    K     = length(mixtures)

    # count nothing mean mixtures
    nMM = 0
    for (i,m) in enumerate(mixtures)
        if isnothing(m.μ)
            nMM += 1
        end
    end

    if initialisation_strategy == "grid"

        minX = fill(-Inf,D)
        maxX = fill(Inf,D)

        for d in 1:D
           minX[d]  = minimum(skipmissing(X[:,d]))
           maxX[d]  = maximum(skipmissing(X[:,d]))
        end



        rangedμ = zeros(nMM,D)
        for d in 1:D
            rangedμ[:,d] = collect(range(minX[d] + (maxX[d]-minX[d])/(nMM*2) , stop=maxX[d] - (maxX[d]-minX[d])/(nMM*2)  , length=nMM))
            # ex: rangedμ[:,d] = collect(range(minX[d], stop=maxX[d], length=nMM))
        end

        j = 1
        for m in mixtures
           if isnothing(m.μ)
               m.μ = rangedμ[j,:]
               j +=1
           end
        end

    elseif initialisation_strategy == "kmeans"
        if !any(ismissing.(X)) # there are no missing
            kmμ = kmeans(X,K,rng=rng)[2]
            for (k,m) in enumerate(mixtures)
               if isnothing(m.μ)
                   m.μ = kmμ[k,:]
               end
            end
        else # missings are present
            # First pass of predictMissing using initialisation_strategy=grid
            #emOut1 = predictMissing(X,K;mixtures=mixtures,verbosity=NONE,minimum_variance=minimum_variance,minimum_covariance=minimum_covariance,initialisation_strategy="grid",rng=rng,maximum_iterations=10) 
            #kmμ = kmeans(emOut1.X̂,K,rng=rng)[2]
            # replicate here code of predictMissing as this has been modev to a subsequent module Imputation, so not available here
            emOutInner = gmm(X,K;mixtures=mixtures,verbosity=NONE,minimum_variance=minimum_variance,minimum_covariance=minimum_covariance,initialisation_strategy="grid",rng=rng,maximum_iterations=10) 
            (N,D) = size(X)
            XMask = .! ismissing.(X)
            X̂ = [XMask[n,d] ? X[n,d] : sum([emOutInner.mixtures[k].μ[d] * emOutInner.pₙₖ[n,k] for k in 1:K]) for n in 1:N, d in 1:D ]
            X̂ = identity.(X̂)
            kmμ = kmeans(X̂,K,rng=rng)[2]
            # TODO check how to use the new GMMIputer() but this is defined AFTER the Cluster module, problem !
            
            for (k,m) in enumerate(mixtures)
               if isnothing(m.μ)
                   m.μ = kmμ[k,:]
               end
            end
        end
    else
        @error "initialisation_strategy $initialisation_strategy not supported by this mixture type"
    end

    initVariances!(mixtures,X,minimum_variance=minimum_variance, minimum_covariance=minimum_covariance,rng=rng)

end

"""lpdf(m::SphericalGaussian,x,mask) - Log PDF of the mixture given the observation `x`"""
function lpdf(m::SphericalGaussian,x,mask)
    x  = convert(Vector{nonmissingtype(eltype(x))},x)
    μ  = m.μ[mask]
    σ² = m.σ²
    #d = IsoNormal(μ,ScalMat(length(μ),σ²))
    #return logpdf(d,x)
    return (- (length(x)/2) * log(2π*σ²)  -  norm(x-μ)^2/(2σ²))
end

"""lpdf(m::DiagonalGaussian,x,mask) - Log PDF of the mixture given the observation `x`"""
function lpdf(m::DiagonalGaussian,x,mask)
    x  = convert(Vector{nonmissingtype(eltype(x))},x)
    μ  = m.μ[mask]
    σ² = m.σ²[mask]
    d  = DiagNormal(μ,PDiagMat(σ²))
    return logpdf(d,x)
end

"""lpdf(m::FullGaussian,x,mask) - Log PDF of the mixture given the observation `x`"""
function lpdf(m::FullGaussian,x,mask)
    x   = convert(Vector{nonmissingtype(eltype(x))},x)
    μ   = m.μ[mask]
    nmd = length(μ)
    σ²  = reshape(m.σ²[mask*mask'],(nmd,nmd))
    σ²  = σ² + max(eps(), -2minimum(eigvals(σ²))) * I # Improve numerical stability https://stackoverflow.com/q/57559589/1586860 (-2 * minimum...) https://stackoverflow.com/a/35612398/1586860

    #=
    try
      d      = FullNormal(μ,PDMat(σ²))
      return logpdf(d,x)
    catch
        println(σ²)
        println(mask)
        println(μ)
        println(x)
        println(σ²^(-1))
        error("Failed PDMat")
    end
    =#
    diff = x .- μ
    #a = det(σ²)
    #b = log(max(a,eps()))
    #return -(nmd/2)*log(2pi)-(1/2)*b-(1/2)*diff'*σ²^(-1)*diff
    return -(nmd/2)*log(2pi)-(1/2)log(max(det(σ²),eps()))-(1/2)*diff'*σ²^(-1)*diff


end

"""
$(TYPEDSIGNATURES)

Return the number of learnable parameters of the mixture model, that is the number of parameters of the individual distribution multiplied by the number of distributions used.

Used to compute the BIC/AIC
"""
npar(mixtures::Array{T,1}) where {T <: AbstractMixture} = nothing 
npar(mixtures::Array{T,1}) where {T <: SphericalGaussian} = length(mixtures) * length(mixtures[1].μ) + length(mixtures) # K * D + K
npar(mixtures::Array{T,1}) where {T <: DiagonalGaussian}  = length(mixtures) * length(mixtures[1].μ) + length(mixtures) * length(mixtures[1].μ) # K * D + K * D
npar(mixtures::Array{T,1}) where {T <: FullGaussian} = begin K = length(mixtures); D = length(mixtures[1].μ); K * D + K * (D^2+D)/2 end


function updateVariances!(mixtures::Array{T,1}, X, pₙₖ; minimum_variance=0.25, minimum_covariance = 0.0) where {T <: SphericalGaussian}

    # debug stuff..
    #X = [1 10 20; 1.2 12 missing; 3.1 21 41; 2.9 18 39; 1.5 15 25]
    #m1 = SphericalGaussian(μ=[1.0,15,21],σ²=5.0)
    #m2 = SphericalGaussian(μ=[3.0,20,30],σ²=10.0)
    #mixtures= [m1,m2]
    #pₙₖ = [0.9 0.1; 0.8 0.2; 0.1 0.9; 0.1 0.9; 0.4 0.6]
    #Xmask = [true true true; true true false; true true true; true true true; true true true]
    #minimum_variance=0.25
    # ---

    (N,D) = size(X)
    K = length(mixtures)
    Xmask     =  .! ismissing.(X)
    XdimCount = sum(Xmask, dims=2)

    #    #σ² = [sum([pⱼₓ[n,j] * norm(X[n,:]-μ[j,:])^2 for n in 1:N]) for j in 1:K ] ./ (nⱼ .* D)
    for k in 1:K
        nom = 0.0
        den = dot(XdimCount,pₙₖ[:,k])
        m = mixtures[k]
        for n in 1:N
            if any(Xmask[n,:])
                nom += pₙₖ[n,k] * norm(X[n,Xmask[n,:]]-m.μ[Xmask[n,:]])^2
            end
        end
        if(den> 0 && (nom/den) > minimum_variance)
            m.σ² = nom/den
        else
            m.σ² = minimum_variance
        end
    end

end

function updateVariances!(mixtures::Array{T,1}, X, pₙₖ; minimum_variance=0.25, minimum_covariance = 0.0) where {T <: DiagonalGaussian}
    # debug stuff..
    #X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
    #m1 = DiagonalGaussian([1.0,10.0],[5.0,5.0])
    #m2 = DiagonalGaussian([4.0,40.0],[10.0,10.0])
    #m3 = DiagonalGaussian([4.0,-2.0],[5.0,5.0])
    #mixtures= [m1,m2,m3]
    #pₙₖ = [0.9 0.1 0; 0.7 0.1 0.1; 0.8 0.2 0; 0.7 0.3 0; 0.1 0.9 0; 0.4 0.4 0.2; 0.1 0.9 0; 0.2 0.1 0.7 ; 0 0.1 0.9]
    #minimum_variance=0.25
    # ---

    (N,D) = size(X)
    K = length(mixtures)
    Xmask     =  .! ismissing.(X)
    #XdimCount = sum(Xmask, dims=2)

    #    #σ² = [sum([pⱼₓ[n,j] * norm(X[n,:]-μ[j,:])^2 for n in 1:N]) for j in 1:K ] ./ (nⱼ .* D)
    for k in 1:K
        m = mixtures[k]
        for d in 1:D
            nom = 0.0
            den = 0.0
            for n in 1:N
                if Xmask[n,d]
                    nom += pₙₖ[n,k] * (X[n,d]-m.μ[d])^2
                    den += pₙₖ[n,k]
                end
            end
            if(den > 0 )
                m.σ²[d] = max(nom/den,minimum_variance)
            else
                m.σ²[d] = minimum_variance
            end
        end
    end

end

function updateVariances!(mixtures::Array{T,1}, X, pₙₖ; minimum_variance=0.25, minimum_covariance = 0.0) where {T <: FullGaussian}

    # debug stuff..
    #X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
    #m1 = FullGaussian([1.0,10.0],[5.0 1; 1.0 5.0])
    #m2 = FullGaussian([4.0,40.0],[10.0 1.0; 1.0 10.0])
    #m3 = FullGaussian([4.0,-2.0],[5.0 1; 1.0 5.0])
    #mixtures= [m1,m2,m3]
    #pₙₖ = [0.9 0.1 0; 0.7 0.1 0.1; 0.8 0.2 0; 0.7 0.3 0; 0.1 0.9 0; 0.4 0.4 0.2; 0.1 0.9 0; 0.2 0.1 0.7 ; 0 0.1 0.9]
    #minimum_variance=0.25
    # ---

    (N,D) = size(X)
    K = length(mixtures)

    # NDDMAsk is true only if both (N,D1) and (N,D2) are nonmissing values
    NDDMask = fill(false,N,D,D)
    for n in 1:N
        for d1 in 1:D
            for d2 in 1:D
                if !ismissing(X[n,d1]) && !ismissing(X[n,d2])
                    NDDMask[n,d1,d2] = true
                end
            end
        end
    end


    #    #σ² = [sum([pⱼₓ[n,j] * norm(X[n,:]-μ[j,:])^2 for n in 1:N]) for j in 1:K ] ./ (nⱼ .* D)
    for k in 1:K
        m = mixtures[k]
        for d2 in 1:D # out var matrix col
            for d1 in 1:D # out var matrix row
                if d1 >= d2 # lower half of triang
                    nom = 0.0
                    den = 0.0
                    for n in 1:N
                        if NDDMask[n,d1,d2]
                            nom += pₙₖ[n,k] * (X[n,d1]-m.μ[d1])*(X[n,d2]-m.μ[d2])
                            den += pₙₖ[n,k]
                        end
                    end
                    if(den > 0 )
                        if d1 == d2
                            m.σ²[d1,d2] = max(nom/den,minimum_variance)
                        else
                            m.σ²[d1,d2] = max(nom/den,minimum_covariance)
                        end
                    else
                        if d1 == d2
                           m.σ²[d1,d2] = minimum_variance
                        else
                          #m.σ²[d1,d2] = minimum_variance-0.01 # to avoid singularity in all variances equal to minimum_variance
                          m.σ²[d1,d2] = minimum_covariance
                        end
                    end
                else # upper half of the matrix
                    m.σ²[d1,d2] = m.σ²[d2,d1]
                end
            end
        end
    end

end

"""
update_parameters!(mixtures::Array{T,1}, X, pₙₖ; minimum_variance=0.25, minimum_covariance)

Find and set the parameters that maximise the likelihood (m-step in the EM algorithm)

"""
#https://github.com/davidavdav/GaussianMixtures.jl/blob/master/src/train.jl
function update_parameters!(mixtures::Array{T,1}, X, pₙₖ; minimum_variance=0.25, minimum_covariance = 0.0) where {T <: AbstractGaussian}
    # debug stuff..
    #X = [1 10 20; 1.2 12 missing; 3.1 21 41; 2.9 18 39; 1.5 15 25]
    #m1 = SphericalGaussian(μ=[1.0,15,21],σ²=5.0)
    #m2 = SphericalGaussian(μ=[3.0,20,30],σ²=10.0)
    #mixtures= [m1,m2]
    #pₙₖ = [0.9 0.1; 0.8 0.2; 0.1 0.9; 0.1 0.9; 0.4 0.6]
    #Xmask = [true true true; true true false; true true true; true true true; true true true]

    (N,D) = size(X)
    K = length(mixtures)
    Xmask     =  .! ismissing.(X)

    #nₖ = sum(pₙₖ,dims=1)'
    #n  = sum(nₖ)
    #pₖ = nₖ ./ n

    nkd = fill(0.0,K,D)
    #nkd = [sum(pₙₖ[Xmask[:,d],k]) for k in 1:K, d in 1:D] # number of point associated to a given mixture for a specific dimension


    # updating μ...
    for k in 1:K
        m = mixtures[k]
        for d in 1:D
            nkd[k,d] = sum(pₙₖ[Xmask[:,d],k])
            if nkd[k,d] > 1
                m.μ[d] = sum(pₙₖ[Xmask[:,d],k] .* X[Xmask[:,d],d])/nkd[k,d]
            end
        end
    end

    updateVariances!(mixtures, X, pₙₖ; minimum_variance=minimum_variance, minimum_covariance=minimum_covariance)
end
