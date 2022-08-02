# Beta Machine Learning Toolkit

 _Machine Learning made simple :-)_

<!-- _BetaML: makes simple machine learning tasks easy, and complex machine learning tasks possible._ -->

<img src="assets/BetaML_logo.png" width="300" valign="middle"/> &nbsp;&nbsp;&nbsp;<img src="assets/microExample_white.png" width="500" valign="middle"/>

The **Beta Machine Learning Toolkit** is a repository with several Machine Learning algorithms, started from implementing in the Julia language the concepts taught in the [MITX 6.86x - Machine Learning with Python: from Linear Models to Deep Learning](https://www.edx.org/course/machine-learning-with-python-from-linear-models-to) course (note we bear no affiliation with that course).

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://sylvaticus.github.io/BetaML.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://sylvaticus.github.io/BetaML.jl/dev)
[![DOI](https://joss.theoj.org/papers/10.21105/joss.02849/status.svg)](https://doi.org/10.21105/joss.02849)
[![Build status](https://github.com/sylvaticus/BetaML.jl/workflows/CI/badge.svg)](https://github.com/sylvaticus/BetaML.jl/actions)
[![codecov.io](http://codecov.io/github/sylvaticus/BetaML.jl/coverage.svg?branch=master)](http://codecov.io/github/sylvaticus/BetaML.jl?branch=master)


Theoretical notes describing most of these algorithms are at the companion repository https://github.com/sylvaticus/MITx_6.86x.

The focus of the library is skewed toward user-friendliness rather than computational efficiency, the code is (relatively) easy to read and, for the algorithms implementation, uses mostly Julia core without external libraries (a little bit like [numpy-ml](https://github.com/ddbourgin/numpy-ml) for Python-Numpy) but it is not heavily optimised (and GPU is not supported).
. For excellent and mature machine learning algorithms in Julia that support huge datasets or to organise complex and partially automated pipelines of algorithms please consider the packages in the above section "Alternative packages".

As the focus is on simplicity, functions have pretty longer but more explicit names than usual.. for example the `Dense` layer is a `DenseLayer`, the `RBF` kernel is `radialKernel`, etc.
As we didn't aim for heavy optimisation, we were able to keep the API (Application Programming Interface) both beginner-friendly and flexible. Contrary to established packages, most methods provide reasonable defaults that can be overridden when needed (like the neural network optimiser, the verbosity level, or the loss function).
For example, one can implement its own layer as a subtype of the abstract type `Layer` or its own optimisation algorithm as a subtype of `OptimisationAlgorithm` or even specify its own distance metric in the clustering `Kmedoids` algorithm..

That said, Julia is a relatively fast language and most hard job is done in multithreaded functions or using matrix operations whose underlying libraries may be multithreaded, so it is reasonably fast for small exploratory tasks and mid-size analysis (basically everything that holds in your PC's memory).

## Documentation

Please refer to the package documentation ([stable](https://sylvaticus.github.io/BetaML.jl/stable) | [dev](https://sylvaticus.github.io/BetaML.jl/dev)) or use the Julia inline package system (just press the question mark `?` and then, on the special help prompt `help?>`, type the module or function name). The package documentation is made of two distinct parts. The first one is an extensively commented tutorial that covers most of the library, the second one is the reference manual covering the library's API.

We currently implemented the following modules in BetaML: [Perceptron](https://sylvaticus.github.io/BetaML.jl/dev/Perceptron.html) (linear and kernel-based classifiers), [Trees](https://sylvaticus.github.io/BetaML.jl/dev/Trees.html) (Decision Trees and Random Forests), [Nn](https://sylvaticus.github.io/BetaML.jl/dev/Nn.html) (Neural Networks), [Clustering](https://sylvaticus.github.io/BetaML.jl/dev/Clustering.html) (Kmean, Kmenoids, Expectation-Maximisation, Missing value imputation, ...) and [Utils](https://sylvaticus.github.io/BetaML.jl/dev/Utils.html).


If you are looking for an introductory book on Julia, have a look on "[Julia Quick Syntax Reference](https://www.julia-book.com/)"(Apress,2019).

The package can be easily used in R or Python employing [JuliaCall](https://github.com/Non-Contradiction/JuliaCall) or [PyJulia](https://github.com/JuliaPy/pyjulia) respectively, see the documentation tutorial on the "Getting started" section.

### Examples

!!! Note
    We are currently implementing a new "V2" api that further simplify the library usage using a "standard" `mod = Model([Options])`, `train!(mod,X,[Y])`, `predict(mod,[X])` workflow. In BetaML v0.7 this new API is still experimantal, as documentation and implementation is not completed. We plan to make it the default API in BetaML 0.8, when the current API will be dimmed deprecated.

We see how to use three different algorithms to learn the relation between floral sepals and petal measures (first 4 columns) and the specie's name (5th column) in the famous [iris flower dataset](https://en.wikipedia.org/wiki/Iris_flower_data_set).

The first two algorithms are example of _supervised_ learning, the third one of _unsupervised_ learning.

- **Using Random Forests for classification**

```julia
using DelimitedFiles, BetaML

iris  = readdlm(joinpath(dirname(Base.find_package("BetaML")),"..","test","data","iris.csv"),',',skipstart=1)
x = iris[:,1:4]
y = iris[:,5]
((xtrain,xtest),(ytrain,ytest)) = partition([x,y],[0.7,0.3])
myForest       = buildForest(xtrain,ytrain,30)
ŷtrain         = predict(myForest, xtrain)
ŷtest          = predict(myForest, xtest)
trainAccuracy  = accuracy(ŷtrain,ytrain) # 1.00
testAccuracy   = accuracy(ŷtest,ytest)   # 0.956
ConfusionMatrix(ŷtest,ytest) |> print    # For details
```

- **Using an Artificial Neural Network for multinomial categorisation**

```julia
# Load Modules
using BetaML, DelimitedFiles, Random, StatsPlots # Load the main module and ausiliary modules
Random.seed!(123); # Fix the random seed (to obtain reproducible results)

# Load the data
iris     = readdlm(joinpath(dirname(Base.find_package("BetaML")),"..","test","data","iris.csv"),',',skipstart=1)
iris     = iris[shuffle(axes(iris, 1)), :] # Shuffle the records, as they aren't by default
x        = convert(Array{Float64,2}, iris[:,1:4])
y        = map(x->Dict("setosa" => 1, "versicolor" => 2, "virginica" =>3)[x],iris[:, 5]) # Convert the target column to numbers
y_oh     = oneHotEncoder(y) # Convert to One-hot representation (e.g. 2 => [0 1 0], 3 => [0 0 1])

# Split the data in training/testing sets
((xtrain,xtest),(ytrain,ytest),(ytrain_oh,ytest_oh)) = partition([x,y,y_oh],[0.8,0.2],shuffle=false)
(ntrain, ntest) = size.([xtrain,xtest],1)

# Define the Artificial Neural Network model
l1   = DenseLayer(4,10,f=relu) # Activation function is ReLU
l2   = DenseLayer(10,3)        # Activation function is identity by default
l3   = VectorFunctionLayer(3,3,f=softmax) # Add a (parameterless) layer whose activation function (softMax in this case) is defined to all its nodes at once
mynn = buildNetwork([l1,l2,l3],squaredCost,name="Multinomial logistic regression Model Sepal") # Build the NN and use the squared cost (aka MSE) as error function (crossEntropy could also be used)

# Training it (default to ADAM)
res = train!(mynn,scale(xtrain),ytrain_oh,epochs=100,batchSize=6) # Use optAlg=SGD() to use Stochastic Gradient Descent instead

# Test it
ŷtrain        = predict(mynn,scale(xtrain))   # Note the scaling function
ŷtest         = predict(mynn,scale(xtest))
trainAccuracy = accuracy(ŷtrain,ytrain,tol=1) # 0.983
testAccuracy  = accuracy(ŷtest,ytest,tol=1)   # 1.0

# Visualise results
testSize    = size(ŷtest,1)
ŷtestChosen =  [argmax(ŷtest[i,:]) for i in 1:testSize]
groupedbar([ytest ŷtestChosen], label=["ytest" "ŷtest (est)"], title="True vs estimated categories") # All records correctly labelled !
plot(0:res.epochs,res.ϵ_epochs, ylabel="epochs",xlabel="error",legend=nothing,title="Avg. error per epoch on the Sepal dataset")
```

<img src="assets/sepalOutput_results.png" width="400"/> <img src="assets/sepalOutput_errors.png" width="400"/>

- **Using the Expectation-Maximisation algorithm for clustering**

```julia
using BetaML, DelimitedFiles, Random, StatsPlots # Load the main module and ausiliary modules
Random.seed!(123); # Fix the random seed (to obtain reproducible results)

# Load the data
iris     = readdlm(joinpath(dirname(Base.find_package("BetaML")),"..","test","data","iris.csv"),',',skipstart=1)
iris     = iris[shuffle(axes(iris, 1)), :] # Shuffle the records, as they aren't by default
x        = convert(Array{Float64,2}, iris[:,1:4])
x        = scale(x) # normalise all dimensions to (μ=0, σ=1)
y        = map(x->Dict("setosa" => 1, "versicolor" => 2, "virginica" =>3)[x],iris[:, 5]) # Convert the target column to numbers

# Get some ranges of minVariance and minCovariance to test
minVarRange   = collect(0.04:0.05:1.5)
minCovarRange = collect(0:0.05:1.45)

# Run the gmm(em) algorithm for the various cases...
sphOut   = [gmm(x,3,mixtures=[SphericalGaussian() for i in 1:3],minVariance=v, minCovariance=cv, verbosity=NONE) for v in minVarRange, cv in minCovarRange[1:1]]
diagOut  = [gmm(x,3,mixtures=[DiagonalGaussian() for i in 1:3],minVariance=v, minCovariance=cv, verbosity=NONE)  for v in minVarRange, cv in minCovarRange[1:1]]
fullOut  = [gmm(x,3,mixtures=[FullGaussian() for i in 1:3],minVariance=v, minCovariance=cv, verbosity=NONE)  for v in minVarRange, cv in minCovarRange]

# Get the Bayesian information criterion (AIC is also available)
sphBIC  = [sphOut[v,cv].BIC for v in 1:length(minVarRange), cv in 1:1]
diagBIC = [diagOut[v,cv].BIC for v in 1:length(minVarRange), cv in 1:1]
fullBIC = [fullOut[v,cv].BIC for v in 1:length(minVarRange), cv in 1:length(minCovarRange)]

# Compare the accuracy with true categories
sphAcc  = [accuracy(sphOut[v,cv].pₙₖ,y,ignoreLabels=true) for v in 1:length(minVarRange), cv in 1:1]
diagAcc = [accuracy(diagOut[v,cv].pₙₖ,y,ignoreLabels=true) for v in 1:length(minVarRange), cv in 1:1]
fullAcc = [accuracy(fullOut[v,cv].pₙₖ,y,ignoreLabels=true) for v in 1:length(minVarRange), cv in 1:length(minCovarRange)]

plot(minVarRange,[sphBIC diagBIC fullBIC[:,1] fullBIC[:,15] fullBIC[:,30]], markershape=:circle, label=["sph" "diag" "full (cov=0)" "full (cov=0.7)" "full (cov=1.45)"], title="BIC", xlabel="minVariance")
plot(minVarRange,[sphAcc diagAcc fullAcc[:,1] fullAcc[:,15] fullAcc[:,30]], markershape=:circle, label=["sph" "diag" "full (cov=0)" "full (cov=0.7)" "full (cov=1.45)"], title="Accuracies", xlabel="minVariance")
```

<img src="assets/sepalClustersBIC.png" width="400"/> <img src="assets/sepalClustersAccuracy.png" width="400"/>

- **Other examples**

Further examples, with more advanced techniques in order to improve predictions, are provided in the documentation tutorial. At the opposite, very "micro" examples of usage of the various functions can be studied in the unit-tests available in the [`test`](https://github.com/sylvaticus/BetaML.jl/tree/master/test) folder  

## Alternative packages

Category         | Packages
-----------------|-----------------
ML toolkits/pipelines | [ScikitLearn.jl](https://github.com/cstjean/ScikitLearn.jl), [AutoMLPipeline.jl](https://github.com/IBM/AutoMLPipeline.jl), [MLJ.jl](https://joss.theoj.org/papers/10.21105/joss.02704)
Neural Networks |  [Flux.jl](https://fluxml.ai/), [Knet](https://github.com/denizyuret/Knet.jl)
Decision Trees | [DecisionTree.jl](https://github.com/bensadeghi/DecisionTree.jl)
Clustering | [Clustering.jl](https://github.com/JuliaStats/Clustering.jl), [GaussianMixtures.jl](https://github.com/davidavdav/GaussianMixtures.jl)
Missing imputation | [Impute.jl](https://github.com/invenia/Impute.jl)



## TODO

### Short term

- Implement utility functions to do hyper-parameter tuning using cross-validation as back-end

### Mid/Long term

- Add convolutional layers and RNN support
- Reinforcement learning (Markov decision processes)

## Contribute

Contributions to the library are welcome. We are particularly interested in the areas covered in the "TODO" list above, but we are open to other areas as well.
Please however consider that the focus is mostly didactic/research, so clear, easy to read (and well documented) code and simple API with reasonable defaults are more important that highly optimised algorithms. For the same reason, it is fine to use verbose names.
Please open an issue to discuss your ideas or make directly a well-documented pull request to the repository.
While not required by any means, if you are customising BetaML and writing for example your own neural network layer type (by subclassing `AbstractLayer`), your own sampler (by subclassing `AbstractDataSampler`) or your own mixture component (by subclassing `AbstractMixture`), please consider to give it back to the community and open a pull request to integrate them in BetaML.

## Citations

If you use `BetaML` please cite as:

- Lobianco, A., (2021). BetaML: The Beta Machine Learning Toolkit, a self-contained repository of Machine Learning algorithms in Julia. Journal of Open Source Software, 6(60), 2849, https://doi.org/10.21105/joss.02849


```Bibtex
@article{Lobianco2021,
  doi       = {10.21105/joss.02849},
  url       = {https://doi.org/10.21105/joss.02849},
  year      = {2021},
  publisher = {The Open Journal},
  volume    = {6},
  number    = {60},
  pages     = {2849},
  author    = {Antonello Lobianco},
  title     = {BetaML: The Beta Machine Learning Toolkit, a self-contained repository of Machine Learning algorithms in Julia},
  journal   = {Journal of Open Source Software}
}
```


## Acknowledgements

The development of this package at the _Bureau d'Economie Théorique et Appliquée_ (BETA, Nancy) was supported by the French National Research Agency through the [Laboratory of Excellence ARBRE](http://mycor.nancy.inra.fr/ARBRE/), a part of the “Investissements d'Avenir” Program (ANR 11 – LABX-0002-01).

[![BLogos](assets/logos_betaumr.png)](hhttp://www.beta-umr7522.fr/)
