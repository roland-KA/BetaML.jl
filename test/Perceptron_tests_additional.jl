using Test
using DelimitedFiles, LinearAlgebra
import MLJBase
const Mlj = MLJBase
import StatisticalMeasures
using StableRNGs
rng = StableRNG(123)
using BetaML.Perceptron

println("*** Additional testing for the Perceptron algorithms...")

println("Testing MLJ interface for Perceptron models....")

X, y                      = Mlj.@load_iris

model                     = LinearPerceptron()
regressor                 = Mlj.machine(model, X, y)
Mlj.evaluate!(regressor, resampling=Mlj.CV(), measure=StatisticalMeasures.LogLoss())

model                     = KernelPerceptron()
regressor                 = Mlj.machine(model, X, y)
Mlj.evaluate!(regressor, resampling=Mlj.CV(), measure=StatisticalMeasures.LogLoss())

model                     = Pegasos()
regressor                 = Mlj.machine(model, X, y)
Mlj.evaluate!(regressor, resampling=Mlj.CV(), measure=StatisticalMeasures.LogLoss())
