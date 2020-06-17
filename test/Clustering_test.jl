using Test
#using DelimitedFiles, LinearAlgebra

import Random:seed!
seed!(123)

using BetaML.Clustering


println("*** Testing Clustering...")

# ==================================
# New test
# ==================================
println("Testing initRepreserntative...")

Z₀ = initRepresentatives([1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.6 38],2,initStrategy="given",Z₀=[1.7 15; 3.6 40])

@test isapprox(Z₀,[1.7  15.0; 3.6  40.0])

# ==================================
# New test
# ==================================
println("Testing kmeans...")

(clIdx,Z) = kmeans([1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.3 38; 5.1 -2.3; 5.2 -2.4],3)

@test clIdx == [2, 2, 2, 2, 3, 3, 3, 1, 1]
#@test (clIdx,Z) .== ([2, 2, 2, 2, 3, 3, 3, 1, 1], [5.15 -2.3499999999999996; 1.5 11.075; 3.366666666666667 36.666666666666664])

# ==================================
# New test
# ==================================
println("Testing kmedoids...")
(clIdx,Z) = kmedoids([1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.3 38; 5.1 -2.3; 5.2 -2.4],3,initStrategy="grid")
@test clIdx == [2, 2, 2, 2, 3, 3, 3, 1, 1]


# ==================================
# New test
# ==================================
println("Testing mixture initialisation and log-pdf...")

m1 = SphericalGaussian()
m2 = SphericalGaussian(μ=[1.1,2,3])
m3 = SphericalGaussian(σ²=10.2)
mixtures = [m1,m2,m3]
X = [1 10 20; 1.2 12 missing; 3.1 21 41; 2.9 18 39; 1.5 15 25]
mask = [true, true, false]
initMixtures!(mixtures,X,minVariance=0.25)
@test sum([sum(m.μ) for m in mixtures]) ≈ 102.2
@test sum([sum(m.σ²) for m in mixtures]) ≈ 19.651086419753085
@test lpdf(m1,X[2,:][mask],mask) ≈ -3.818323669882357

m1 = DiagonalGaussian()
m2 = DiagonalGaussian(μ=[1.1,2,3])
m3 = DiagonalGaussian(σ²=[0.1,11,25.0])
mixtures = [m1,m2,m3]
initMixtures!(mixtures,X,minVariance=0.25)
@test sum([sum(m.σ²) for m in mixtures]) ≈ 291.27933333333334
@test lpdf(m1,X[2,:][mask],mask) ≈ -3.4365786131066063

m1 = FullGaussian()
m2 = FullGaussian(μ=[1.1,2,3])
m3 = FullGaussian(σ²=[0.1 0.2 0.5; 0 2 0.8; 1 0 5])
mixtures = [m1,m2,m3]
initMixtures!(mixtures,X,minVariance=0.25)
@test sum([sum(m.σ²) for m in mixtures]) ≈ 264.77933333333334
@test lpdf(m1,X[2,:][mask],mask) ≈ -3.4365786131066063

# ==================================
# New test
# ==================================
println("Testing em...")

#clusters = emGM([1 10.5;1.5 0; 1.8 8; 1.7 15; 3.2 40; 0 0; 3.3 38; 0 -2.3; 5.2 -2.4],3,msgStep=0,missingValue=0)
#@test isapprox(clusters.BIC,-39.7665224029492)
#clusters = em([1 10.5;1.5 0; 1.8 8; 1.7 15; 3.2 40; 0 0; 3.3 38; 0 -2.3; 5.2 -2.4],3,msgStep=0)


# ==================================
# New test
# ==================================
#println("Testing emGMM...")
#X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
#out = fillSparseGMM(X,3,msgStep=0)
#@test isapprox(out.X̂[2,2],14.177888746691615)
