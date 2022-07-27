using Test
#using DelimitedFiles, LinearAlgebra

#using StableRNGs
#rng = StableRNG(123)

import MLJBase
const Mlj = MLJBase
import Distributions
using BetaML

TESTRNG = FIXEDRNG # This could change...
#TESTRNG = StableRNG(123)

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

X = [1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.3 38; 5.1 -2.3; 5.2 -2.4]

(clIdxKMeans,Z) = kmeans(X,3,initStrategy="grid",rng=copy(TESTRNG))
@test clIdxKMeans == [2, 2, 2, 2, 3, 3, 3, 1, 1]
#@test (clIdx,Z) .== ([2, 2, 2, 2, 3, 3, 3, 1, 1], [5.15 -2.3499999999999996; 1.5 11.075; 3.366666666666667 36.666666666666664])
m = KMeansModel(nClasses=3,verbosity=NONE, initStrategy="grid",rng=copy(TESTRNG))
train!(m,X)
classes = predict(m)
@test clIdxKMeans == classes
X2 = [1.5 11; 3 40; 3 40; 5 -2]
classes2 = predict(m,X2)
@test classes2 == [2,3,3,1]
train!(m,X2)
classes3 = predict(m)
@test classes3 == [2,3,3,1]

# ==================================
# New test
# ==================================
println("Testing kmedoids...")
(clIdxKMedoids,Z) = kmedoids([1 10.5;1.5 10.8; 1.8 8; 1.7 15; 3.2 40; 3.6 32; 3.3 38; 5.1 -2.3; 5.2 -2.4],3,initStrategy="shuffle",rng=copy(TESTRNG))
@test clIdxKMedoids == [1, 1, 1, 1, 2, 2, 2, 3, 3]
m = KMedoidsModel(nClasses=3,verbosity=NONE, initStrategy="shuffle",rng=copy(TESTRNG))
train!(m,X)
classes = predict(m)
@test clIdxKMedoids == classes
X2 = [1.5 11; 3 40; 3 40; 5 -2]
classes2 = predict(m,X2)
@test classes2 == [1,2,2,3]
train!(m,X2)
classes3 = predict(m)
@test classes3 == [1,2,2,3]

# ==================================
# New test
# ==================================
println("Testing mixture initialisation and log-pdf...")

m1 = SphericalGaussian()
m2 = SphericalGaussian([1.1,2,3])
m3 = SphericalGaussian(nothing,10.2)
mixtures = [m1,m2,m3]
X = [1 10 20; 1.2 12 missing; 3.1 21 41; 2.9 18 39; 1.5 15 25]
initMixtures!(mixtures,X,minVariance=0.25,rng=copy(TESTRNG))
@test sum([sum(m.μ) for m in mixtures]) ≈ 102.2
@test sum([sum(m.σ²) for m in mixtures]) ≈ 19.651086419753085
mask = [true, true, false]
@test lpdf(m1,X[2,:][mask],mask) ≈ -3.461552516784797

m1 = DiagonalGaussian()
m2 = DiagonalGaussian([1.1,2,3])
m3 = DiagonalGaussian(nothing,[0.1,11,25.0])
mixtures = [m1,m2,m3]
initMixtures!(mixtures,X,minVariance=0.25,rng=copy(TESTRNG))
@test sum([sum(m.σ²) for m in mixtures]) ≈ 291.27933333333334
@test lpdf(m1,X[2,:][mask],mask) ≈ -3.383055441795939

m1 = FullGaussian()
m2 = FullGaussian([1.1,2,3])
m3 = FullGaussian(nothing,[0.1 0.2 0.5; 0 2 0.8; 1 0 5])
mixtures = [m1,m2,m3]
initMixtures!(mixtures,X,minVariance=0.25,rng=copy(TESTRNG))
@test sum([sum(m.σ²) for m in mixtures]) ≈ 264.77933333333334
@test lpdf(m1,X[2,:][mask],mask) ≈ -3.383055441795939

# ==================================
# New test
# ==================================
println("Testing gmm...")
X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
clusters = gmm(X,3,verbosity=NONE, initStrategy="grid",rng=copy(TESTRNG))
@test isapprox(clusters.BIC,114.1492467835965)
#clusters.pₙₖ
#clusters.pₖ
#clusters.mixtures
#clusters.BIC

# ==================================
# New test
# ==================================
println("Testing predictMissing...")
X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
out = predictMissing(X,3,mixtures=[SphericalGaussian() for i in 1:3],verbosity=NONE, initStrategy="grid",rng=copy(TESTRNG))
@test isapprox(out.X̂[2,2],14.155186593170251)

X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
out2 = predictMissing(X,3,mixtures=[DiagonalGaussian() for i in 1:3],verbosity=NONE, initStrategy="grid",rng=copy(TESTRNG))
@test out2.X̂[2,2] ≈ 14.588514438886131

X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
out3 = predictMissing(X,3,mixtures=[FullGaussian() for i in 1:3],verbosity=NONE, initStrategy="grid",rng=copy(TESTRNG))
@test out3.X̂[2,2] ≈ 11.166652292936876

# ==================================
# NEW TEST
println("Testing MLJ interface for Clustering models....")
X, y                           = Mlj.@load_iris

model                          = KMeans(rng=copy(TESTRNG))
modelMachine                   = Mlj.machine(model, X)
(fitResults, cache, report)    = Mlj.fit(model, 0, X)
distances                      = Mlj.transform(model,fitResults,X)
yhat                           = Mlj.predict(model, fitResults, X)
acc = BetaML.accuracy(Mlj.levelcode.(yhat),Mlj.levelcode.(y),ignoreLabels=true)
@test acc > 0.8

model                          = KMedoids(rng=copy(TESTRNG))
modelMachine                   = Mlj.machine(model, X)
(fitResults, cache, report)    = Mlj.fit(model, 0, X)
distances                      = Mlj.transform(model,fitResults,X)
yhat                           = Mlj.predict(model, fitResults, X)
acc = BetaML.accuracy(Mlj.levelcode.(yhat),Mlj.levelcode.(y),ignoreLabels=true)
@test acc > 0.8

model                       =  GMMClusterer(mixtures=:diag_gaussian,rng=copy(TESTRNG))
modelMachine                =  Mlj.machine(model, X) # DimensionMismatch
(fitResults, cache, report) =  Mlj.fit(model, 0, X)
yhat_prob                   =  Mlj.predict(model, fitResults, X)  # Mlj.transform(model,fitResults,X)
# how to get this ??? Mlj.predict_mode(yhat_prob)
@test Distributions.pdf(yhat_prob[end],2) ≈ 0.5937443601647852

X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]
X = Mlj.table(X)
model                       =  MissingImputator(rng=copy(TESTRNG))
modelMachine                =  Mlj.machine(model,X)
(fitResults, cache, report) = Mlj.fit(model, 0, X)
XD                          =  Mlj.transform(model,fitResults,X)
XDM                         =  Mlj.matrix(XD)
@test isapprox(XDM[2,2],15.441553354222702)
# Use the previously learned structure to imput missings..
Xnew_withMissing            = Mlj.table([1.5 missing; missing 38; missing -2.3; 5.1 -2.3])
XDNew                       = Mlj.transform(model,fitResults,Xnew_withMissing)
XDMNew                      =  Mlj.matrix(XDNew)
@test isapprox(XDMNew[1,2],13.818691793037452)

#=
# Marginally different
XD  == XDNew
Mlj.matrix(XD)  ≈ Mlj.matrix(XDNew)
XDM  == XDMNew

for r in 1:size(XDM,1)
    for c in 1:size(XDM,2)
        if XDM[r,c] != XDMNew[r,c]
            println("($r,$c): $(XDM[r,c]) - $(XDMNew[r,c])")
        end
    end
end
=#


#=
@test Mlj.mean(Mlj.LogLoss(tol=1e-4)(yhat_prob, y)) < 0.0002
Mlj.predict_mode(yhat_prob)
N = size(Mlj.matrix(X),1)
nCl = size(fitResults[2],1)
yhat_matrix = Array{Float64,2}(undef,N,nCl)
[yhat_matrix[n,c]= yhat_prob[n][c] for n in 1:N for c in 1:nCl]
yhat_prob[2]
 Mlj.matrix(yhat_prob)
acc = accuracy(Mlj.levelcode.(yhat),Mlj.levelcode.(y),ignoreLabels=true)
ynorm = Mlj.levelcode.(y)
accuracy(yhat_prob,ynorm,ignoreLabels=true)
@test acc > 0.8
=#





#=
using MLJBase, BetaML
y, _                        =  make_regression(1000, 3, rng=123);
ym                          =  MLJBase.matrix(y)
model                       =  GMM(rng=copy(BetaML.TESTRNG))
(fitResults, cache, report) =  MLJBase.fit(model, 0, nothing, y)
yhat_prob                   =  MLJBase.transform(model,fitResults,y)
yhat_prob                   =  MLJBase.predict(model, fitResults, y)


modelMachine                =  MLJBase.machine(model, nothing, y)
mach                        =  MLJBase.fit!(modelMachine)
yhat_prob                   =  MLJBase.predict(mach, nothing)
=#


println("Testing GMMClusterModel...")
X = [1 10.5;1.5 missing; 1.8 8; 1.7 15; 3.2 40; missing missing; 3.3 38; missing -2.3; 5.2 -2.4]

m = GMMClusterModel(nClasses=3,verbosity=NONE, initStrategy="grid",rng=copy(TESTRNG))
train!(m,X)
probs = predict(m)
gmmOut = gmm(X,3,verbosity=NONE, initStrategy="grid",rng=copy(TESTRNG))
@test gmmOut.pₙₖ == probs

μ_x1alone = hcat([m.par.mixtures[i].μ for i in 1:3]...)
pk_x1alone = m.par.probMixtures

X2 = [2.0 12; 3 20; 4 15; 1.5 11]

m2 = GMMClusterModel(nClasses=3,verbosity=NONE, initStrategy="grid",rng=copy(TESTRNG))
train!(m2,X2)
#μ_x2alone = hcat([m.par.mixtures[i].μ for i in 1:3]...)
probsx2alone = predict(m2)
@test probsx2alone[1,1] < 0.999

probX2onX1model = predict(m,X2)
@test probX2onX1model[1,1] ≈ 0.5214795038476924 

train!(m,X2) # this greately reduces mixture variance
#μ_x1x2 = hcat([m.par.mixtures[i].μ for i in 1:3]...)
probsx2 = predict(m)
@test probsx2[1,1] > 0.999 # it feels more certain as it uses the info of he first training

reset!(m)

#@test isapprox(clusters.BIC,114.1492467835965)
#clusters.pₙₖ
#clusters.pₖ
#clusters.mixtures
#clusters.BIC

#m.hyperparameters