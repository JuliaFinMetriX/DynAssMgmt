using DynAssMgmt
using Base.Test

@testset "Tests for utilities" begin include("utils_tests.jl") end
@testset "Tests of basic econometric functions" begin include("baseEconMetrics_test.jl") end
@testset "Tests of single period strategies" begin include("singlePeriodStrats_tests.jl") end
