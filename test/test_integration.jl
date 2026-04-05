# Tests against the shared TEST_JSON / TEX fixtures (defined in runtests.jl).
# The resolve_tex helper used here is defined in helpers.jl.

@testset "flat scalar keys" begin
    @test resolve_tex(TEX, "data", "baz") == "test"
    @test resolve_tex(TEX, "data", "bar") == "true"
end

@testset "list access" begin
    @test resolve_tex(TEX, "data", "foo", "1") == "0.1"
    @test resolve_tex(TEX, "data", "foo", "2") == "3"
end

@testset "missing key returns ??" begin
    @test resolve_tex(TEX, "data", "foo", "3")        == "??"
    @test resolve_tex(TEX, "data", "not")              == "??"
    @test resolve_tex(TEX, "data", "blah123", "3")        == "??"
    @test resolve_tex(TEX, "data", "blah123", "2", "not") == "??"
    @test resolve_tex(TEX, "data", "blah123", "1", "not") == "??"
    @test resolve_tex(TEX, "data", "blah123", "2", "g", "4") == "??"
end

@testset "nested dict access" begin
    @test resolve_tex(TEX, "data", "blah123", "1", "a")    == "b"
    @test resolve_tex(TEX, "data", "blah123", "1", "test") == "3.1415"
    @test resolve_tex(TEX, "data", "blah123", "2", "c")    == "f"
end

@testset "deeply nested list" begin
    @test resolve_tex(TEX, "data", "blah123", "2", "g", "1") == "x"
    @test resolve_tex(TEX, "data", "blah123", "2", "g", "2") == "yz"
    @test resolve_tex(TEX, "data", "blah123", "2", "g", "3") == "101"
end

@testset "all (full JSON) round-trips" begin
    # The "all" value for a list/dict must round-trip through the JSON parser,
    # confirming both content and valid JSON formatting.
    foo_all = resolve_tex(TEX, "data", "foo")
    @test JSON.parse(foo_all) == [0.1, 3]

    blah1231_all = resolve_tex(TEX, "data", "blah123", "1")
    parsed = JSON.parse(blah1231_all)
    @test parsed["a"] == "b"
    @test parsed["test"] == 3.1415

    g_all = resolve_tex(TEX, "data", "blah123", "2", "g")
    @test JSON.parse(g_all) == ["x", "yz", 101]

    top_all = resolve_tex(TEX, "data")
    parsed_top = JSON.parse(top_all)
    @test parsed_top["baz"] == "test"
    @test parsed_top["foo"] == [0.1, 3]
end
