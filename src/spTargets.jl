# define single-period portfolio target types

# TODO: create super type!
# TODO: create collection of targets

"""
    SinglePeriodSpectrum

Abstract super type for multiple single-period strategies in the cross-section.
"""
abstract type SinglePeriodSpectrum end

"""
    SinglePeriodTarget

Abstract super type for single-period strategies.
"""
abstract type SinglePeriodTarget <: SinglePeriodSpectrum end

"""
    EqualWgts()

Simple equal weights strategy.
"""
struct EqualWgts <: SinglePeriodTarget

end

function apply(xx::EqualWgts, thisUniv::Univ)
    nAss = size(thisUniv)
    equWgts = ones(Float64, nAss) ./ nAss
    PF(equWgts[:])
end

import Base.length
length(xx::SinglePeriodTarget) = 1

getName(xx::EqualWgts) = "Equal weights"

"""
```julia
GMVP()
```

Global minimum variance portfolio strategy.
"""
struct GMVP <: SinglePeriodTarget

end

apply(xx::GMVP, thisUniv::Univ) = PF(gmvp(thisUniv))
getName(xx::GMVP) = "GMVP"

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
getName(xx::TargetVola) = "Vola target: $(round(xx.Vola, 2))"

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
getName(xx::MaxSharpe) = "Maximum Sharpe, risk-free: $xx.RiskFree"

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
getName(xx::TargetMu) = "Target mu: $(round(xx.Mu, 2))"

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

length(xx::EffFront) = xx.NEffPfs
getName(xx::EffFront) = String["Efficient frontier pf. $ii" for ii=1:xx.NEffPfs]

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

getName(xx::DivFrontSigmaTarget) = "Div. and vola target: $(xx.diversTarget), $(round(xx.sigTarget, 2))"

"""
```julia
DivFront(divTarget::Float64, sigTarget::Array{Float64, 1})
```

Multiple portfolios with target diversification level and multiple
volatility targets.
"""
struct DivFront <: SinglePeriodSpectrum
    diversTarget::Float64
    sigTargets::Array{Float64, 1}
end

function apply(xx::DivFront, thisUniv::Univ)
    wgtsArray = sigmaAndDiversTarget(thisUniv, xx.sigTargets, xx.diversTarget)
    pfArray = map(x -> PF(x), wgtsArray)
    pfArray = reshape(pfArray, 1, size(pfArray, 1))
end

length(xx::DivFront) = length(xx.sigTargets)
getName(xx::DivFront) = String["Div. and vola target: $(xx.diversTarget), $(round(thisSig, 2))" for thisSig in xx.sigTargets]

"""
```julia
DivFrontRelativeSigmas(divTarget::Float64, nSigTarget::Int)
```

Multiple portfolios with target diversification level and multiple relative
volatility targets.
"""
struct DivFrontRelativeSigmas <: SinglePeriodSpectrum
    diversTarget::Float64
    NSigTargets::Int64
end

function apply(xx::DivFrontRelativeSigmas, thisUniv::Univ)
    wgtsArray = diversTargetFrontier(thisUniv, xx.NSigTargets, xx.diversTarget)
    pfArray = map(x -> PF(x), wgtsArray)
    pfArray = reshape(pfArray, 1, size(pfArray, 1))
end

length(xx::DivFrontRelativeSigmas) = xx.NSigTargets
getName(xx::DivFrontRelativeSigmas) = String["Div. and relative vola target: $(xx.diversTarget), $ii" for ii=1:xx.NSigTargets]

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
