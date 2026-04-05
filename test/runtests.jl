using Test
import JSON
using json2latex
using json2latex: escape_latex, to_roman, check_name   # internal helpers under test

include("helpers.jl")   # resolve_tex and its sub-functions

# Shared fixtures used by test_convert.jl, test_integration.jl and test_api.jl.
const TEST_JSON = JSON.parsefile(joinpath(@__DIR__, "test.json"); dicttype = OrderedDict)
const TEX = dumps("data", TEST_JSON)

@testset "json2latex" begin
    include("test_escape.jl")
    include("test_convert.jl")
    include("test_integration.jl")
    include("test_api.jl")
    include("test_perf.jl")
end
