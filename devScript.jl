# test types / code during development

cd("/home/chris/scalable/julia/DynAssMgmt/")

# using Gadfly
# using Query
# using PDMats
# using BenchmarkTools

## set up parallel computation
addprocs(2)

## load code
@everywhere begin
    using DataFrames
    using Convex
    using DistributedArrays
    using Plots

    set_default_solver(SCS.SCSSolver(verbose=0))

    include("src/utils.jl")
    include("src/assetAllocationTypes.jl")
    include("src/plotFuncs.jl")
    include("src/pfFuncs.jl")
    include("src/singlePeriodStrats.jl")
    include("src/spTargets.jl")
end

##

plotlyjs()

## load data from disk and transform to reasonable format
rawMus = readcsv("inputData/jochenMus.csv")
rawCovs = readcsv("inputData/jochenCovs.csv")
rawIdxRets = readcsv("inputData/idxReturns.csv")

muTab = rawInputsToDataFrame(rawMus)
covsTab = rawInputsToDataFrame(rawCovs)
idxRets = rawInputsToDataFrame(rawIdxRets)

## get as evolution of universes
univHistory = getUnivEvolFromMatlabFormat(muTab, covsTab)

xx = univHistory
univHistoryShort = UnivEvol(xx.universes[1:50], xx.dates[1:50], xx.assetLabels)

## parallel computation
thisUniv = univHistory.universes[100]

apply(GMVP(), thisUniv)
apply(TargetVola(0.6), thisUniv)
apply(MaxSharpe(), thisUniv)
apply(TargetMu(0.1), thisUniv)

@time xx = apply(GMVP(), univHistory)

##

@time xx = apply(EffFront(10), univHistory)

## define collection of targets
# - over time
# - over targets
# - list of dates
# - list of assets
# - list of targets
#
# - switch between "cross-section" and "over time" perspective
# - overTime vs overTargets
#
# - nObs x nStrats x nAss,
#   where nStrats is possibly grouped into sub-groups (e.g. due to spectra)

## without parallel computation -> for enhanced error checking

nObs, nAss = size(univHistory)
testSigWgts = zeros(Float64, nObs, nAss)
xxps = []
for ii=1:nObs
    xx, xxp = sigmaTarget(univHistory.universes[ii], sigTarget)
    testSigWgts[ii, :] = xx'
    push!(xxps, xxp)
end
testSigWgts

##

thisUniv = univHistory.universes[1757]
sigmaTargetFallback(thisUniv, sigTarget)
xxWgts = sigmaTarget_biSect_quadForm(thisUniv, sigTarget)
xxWgts = sigmaTarget(thisUniv, sigTarget)
pfMoments(thisUniv, )

## visualize given universe

thisUniv = univHistory.universes[1757]

# visualize efficient frontier
effWgts = effFront(thisUniv)
xx1, xx2 = pfMoments(thisUniv, effWgts)

vizPfSpectrum(thisUniv, effWgts)

# visualize gmvp
xxGmvp = gmvp(thisUniv)
vizPf!(thisUniv, xxGmvp)

# visualize maximum sharpe
xxMaxSharpe = maxSharpe(thisUniv)
vizPf!(thisUniv, xxMaxSharpe)

# visualize target sigma
sigTarget = 1.2
xxSigWgts = sigmaTarget(thisUniv, sigTarget)

vizPf!(thisUniv, xxSigWgts)


plot!(sigTarget*sqrt(52)*ones(Float64, 2), [0; 35], seriestype=:line)


##
effMus, effVars = pfMoments(thisUniv, effWgts)

##

plot(sqrt.(effVars), effMus)

##

xxMus, xxVar = pfMoments(univHistory.universes[280], testSigWgts[280, :][:])
sqrt.(xxVar)

##

absDiffs = sum(abs(testSigWgts .- allSigWgts[1:500, :]), 2)

## evaluate all sigma-target portfolios
dailyMus, dailyVars = pfMoments(univHistory, allSigWgts)

## check distances to target

xxCloseEnough = abs.(sqrt.(dailyVars) - sigTarget) .<= 0.001
sum(xxCloseEnough)

##
# inspect days with too much deviation
xxIndsToInspect = find(.!xxCloseEnough)
closeToMaxSigAss = []
for ii in xxIndsToInspect
    xxthisUniv = univHistory.universes[ii]

    # find maximum mu
    xx, xxInd = findmax(xxthisUniv.mus)

    # get associated sigma
    maxSigAsset = sqrt.(diag(xxthisUniv.covs)[xxInd])

    # compare to sigma target portfolio
    foundSigma = sqrt.(dailyVars[ii])

    push!(closeToMaxSigAss, abs(foundSigma - maxSigAsset) < 0.01)
end
closeToMaxSigAss = convert(BitArray, closeToMaxSigAss)
indsToInspect = xxIndsToInspect[.!closeToMaxSigAss]

##

indsToInspect = [280, 621, 724, 1633, 1757, 3624]
sqrt.(dailyVars[indsToInspect])

##

xx1 = sigmaTarget(univHistory.universes[280], sigTarget)

## visualize universe
thisUnivInd = 280
thisUniv = univHistory.universes[thisUnivInd]
plot(thisUniv)
vizPf!(thisUniv, allSigWgts[thisUnivInd, :])
#plot(thisUniv, univHistory.assetLabels)

##


##
# try gmvp
gmvpLevWgts = gmvp_lev(thisUniv)
gmvpWgts = gmvp(thisUniv)

##

sigTarget = 1.7
targetSigWgts = sigmaTarget(thisUniv, sigTarget)
xxMu, xxVar = pfMoments(thisUniv, targetSigWgts)
sqrt(xxVar)

##

targetMu = 0.06
targetMuWgts = muTarget(thisUniv, targetMu)
pfMoments(thisUniv, targetMuWgts)

getUnivExtrema(thisUniv)

## get portfolio moments
vizPf(thisUniv, gmvpWgts)
vizPf!(thisUniv, targetSigWgts)
vizPf!(thisUniv, targetMuWgts)

## plot portfolio moments for single pf over time
allPfMus, allPfVars = pfMoments(univHistory, gmvpLevWgts)
plot(sqrt.(allPfVars)*sqrt.(52), allPfMus.*52, xaxis="Sigma",
    yaxis="Mu", labels = "GMVP")

allPfMus, allPfVars = pfMoments(univHistory, gmvpWgts)
plot!(sqrt.(allPfVars)*sqrt.(52), allPfMus.*52, xaxis="Sigma",
    yaxis="Mu", labels = "GMVP", color=:red)

@time allGmvpWgtsDistributed = map(x -> gmvp(x), DUnivs)
allGmvpWgts = convert(Array, allGmvpWgtsDistributed)
allGmvpWgts = vcat([ii[:]' for ii in allGmvpWgts]...)

sigTarget = 1.12
@time allSigWgtsDistributed = map(x -> cappedSigma(x, sigTarget), DUnivs)
allSigWgts = convert(Array, allSigWgtsDistributed)
allSigWgts = vcat([ii[:]' for ii in allSigWgts]...)

## make area plot for weights
xxGrid = univHistory.dates
xxDats = getNumDates(xxGrid)
xxLabs = univHistory.assetLabels

default(show = true, size=(1400,800))
p = wgtsOverTime(allSigWgts, xxDats, xxLabs)
display(p)

# plot first weights


plot(dailyPfSigs)

## do some checks
xx = sum(allSigWgts, 2)
bar(mean(allSigWgts, 1))

##

@userplot PortfolioComposition

# this shows the shifting composition of a basket of something over a variable
# - "returns" are the dependent variable
# - "weights" are a matrix where the ith column is the composition for returns[i]
# - since each polygon is its own series, you can assign labels easily
@recipe function f(pc::PortfolioComposition)
    weights, returns = pc.args
    n = length(returns)
    weights = cumsum(weights,2)
    seriestype := :shape

	# create a filled polygon for each item
    for c=1:size(weights,2)
        sx = vcat(weights[:,c], c==1 ? zeros(n) : reverse(weights[:,c-1]))
        sy = vcat(returns, reverse(returns))
        @series Plots.isvertical(d) ? (sx, sy) : (sy, sx)
    end
end

tickers = ["IBM", "Google", "Apple", "Intel"]
N = 10
D = length(tickers)
weights = rand(N,D)
weights ./= sum(weights, 2)
returns = sort!((1:N) + D*randn(N))

portfoliocomposition(weights, returns, labels = tickers)

##

plot([0, 0, 1, 1], [0, 1, 1, 0], seriestype=:shape)

##

plot([1.; xxGrid[1:3]; 3], [0.; ones(3); 0], seriestype=:shape)

##
xxGrid = Float64[ii for ii=1:size(allSigWgts, 1)]
xxGrid = [1.; xxGrid; 1.]
plot([1.; xxGrid; xxGrid[end]+1], [0; allSigWgts[:, 1]; 0], seriestype=:shape)

## compute max-sharpe portfolios

@time allMaxSharpeWgtsDistributed = map(x -> maxSharpe(x), DUnivs)
allMaxSharpeWgts = convert(Array, allMaxSharpeWgtsDistributed)
allMaxSharpeWgts = vcat([ii[:]' for ii in allMaxSharpeWgts]...)
