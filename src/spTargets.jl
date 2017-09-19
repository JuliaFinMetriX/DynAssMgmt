# define single-period portfolio target types

# TODO: create super type!
# TODO: create collection of targets

abstract type SinglePeriodTarget end
abstract type SinglePeriodSpectrum end

"""
```julia
GMVP()
```    

Global minimum variance portfolio strategy.
"""
struct GMVP <: SinglePeriodTarget

end

apply(xx::GMVP, thisUniv::Univ) = PF(gmvp(thisUniv))

"""
```julia
TargetVola(vol::Float64)
```    

Target portfolio volatility strategy.
"""
struct TargetVola <: SinglePeriodTarget
    Vola::Float64
end

apply(xx::TargetVola, thisUniv::Univ) = PF(sigmaTarget(thisUniv, xx.Vola))

# vola relative to efficient frontier (maximum mu / gmvp mu range)
"""
```julia
RelativeTargetVola(vol::Float64)
```    

Target portfolio volatility strategy, with volatility target given in relative
terms. Target is relative with regards to maximum mu and gmvp.
"""
struct RelativeTargetVola <: SinglePeriodTarget
    Vola::Float64
end

"""
```julia
MaxSharpe()
MaxSharpe(rf::Float64)
```    

Maximum Sharpe-ratio portfolio strategy. Optional input can be used to specify
the risk-free rate.
"""
struct MaxSharpe <: SinglePeriodTarget
    RiskFree::Float64
end

MaxSharpe() = MaxSharpe(0.0)
apply(xx::MaxSharpe, thisUniv::Univ) = PF(maxSharpe(thisUniv))

"""
```julia
TargetMu(mu::Float64)
```    

Target portfolio expectation strategy.
"""
struct TargetMu <: SinglePeriodTarget
    Mu::Float64
end

apply(xx::TargetMu, thisUniv::Univ) = PF(muTarget(thisUniv, xx.Mu))

"""
```julia
EffFront(npfs::Int64)
```    

Efficient frontier portfolio spectrum. Single input determines the number of
portfolios on the efficient frontier.
"""
struct EffFront <: SinglePeriodSpectrum
    NEffPfs::Int64
end

function apply(xx::EffFront, thisUniv::Univ)
    wgtsArray = effFront(thisUniv; nEffPfs = xx.NEffPfs)
    pfArray = map(x -> PF(x), wgtsArray)
    pfArray = reshape(pfArray, 1, size(pfArray, 1))
end

function getSingleTargets(someFront::EffFront)
    # get number of portfolios
    nPfs = someFront.NEffPfs

    allSingleStrats = [RelativeTargetVola(ii./nPfs) for ii=1:nPfs]
end

"""
```julia
DivFrontSigmaTarget(divTarget::Float64, sigTarget::Float64)
```    

Portfolio strategy with target diversification level and target volatility.
"""
struct DivFrontSigmaTarget <: SinglePeriodTarget
    diversTarget::Float64
    sigTarget::Float64
end

struct DivFront <: SinglePeriodSpectrum
    diversTarget::Float64
    sigTargets::Array{Float64, 1}
end

function apply(xx::DivFront, thisUniv::Univ)
    wgtsArray = sigmaAndDiversTarget(thisUniv, xx.sigTargets, xx.diversTarget)
    pfArray = map(x -> PF(x), wgtsArray)
    pfArray = reshape(pfArray, 1, size(pfArray, 1))
end

"""
```julia
getSingleTargets(someDivFront::DivFront)
```    

Transform a spectrum of single-period portfolio strategies into an array of
`SinglePeriodTarget`.
"""
function getSingleTargets(someDivFront::DivFront)
    # get number of portfolios
    sigTargets = someDivFront.sigTargets
    diversTarget = someDivFront.diversTarget

    nPfs = length(sigTargets)
    allSingleStrats = [DivFrontSigmaTarget(diversTarget, sigTargets[ii]) for ii=1:nPfs]
end


## generalization of apply

# make generalization to UnivEvols including potential parallelization
"""
```julia
apply(thisTarget::SinglePeriodTarget, univHistory::UnivEvol)
```    

Apply some single-period strategy to multiple universes. Automatically uses
parallelization when multiple processes are running.
"""
function apply(thisTarget::SinglePeriodTarget, univHistory::UnivEvol)
    # check for multiple processes

    nProcesses = nprocs()

    if nProcesses == 1
        allPfs = [apply(thisTarget, x) for x in univHistory.universes]
        allPfs = reshape(allPfs, size(allPfs, 1), 1)

    elseif nProcesses > 1

        # distribute historic universes over processes
        DUnivs = distribute(univHistory.universes)

        allWgtsDistributed = map(x -> apply(thisTarget, x), DUnivs)
        allPfs = convert(Array, allWgtsDistributed)

        allPfs = reshape(allPfs, size(allPfs, 1), 1)

    end

end
