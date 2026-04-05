@testset "to_roman" begin
    @test to_roman(1)    == "I"
    @test to_roman(2)    == "II"
    @test to_roman(3)    == "III"
    @test to_roman(4)    == "IV"
    @test to_roman(5)    == "V"
    @test to_roman(9)    == "IX"
    @test to_roman(10)   == "X"
    @test to_roman(14)   == "XIV"
    @test to_roman(40)   == "XL"
    @test to_roman(400)  == "CD"
    @test to_roman(1994) == "MCMXCIV"
    @test_throws ArgumentError to_roman(0)
    @test_throws ArgumentError to_roman(-1)
end

@testset "check_name" begin
    @test (check_name("data"); true)
    @test (check_name("myVar"); true)
    @test_throws ArgumentError check_name("bad_name")
    @test_throws ArgumentError check_name("bad1")
    @test_throws ArgumentError check_name("")
    # Unicode letters are not valid LaTeX command-name characters
    @test_throws ArgumentError check_name("naïve")
    @test_throws ArgumentError check_name("αβ")
end

@testset "dumps — structure" begin
    # Boilerplate wrapping
    tex = dumps("data", OrderedDict("x" => 1))
    @test startswith(tex, "\\makeatletter%\n")
    @test endswith(tex, "%\n\\makeatother%")
    @test occursin("\\newcommand\\data[1][all]{%", tex)

    # Single scalar key
    tex = dumps("data", OrderedDict("foo" => 42))
    @test occursin("\\ifnum\\pdfstrcmp{#1}{foo}=0%", tex)
    @test occursin("42", tex)

    # Missing-key fallback
    @test occursin("??", tex)

    # Nested list relays to a sub-command (1-based by default)
    tex = dumps("data", OrderedDict("arr" => [10, 20]))
    @test occursin("\\let\\data@out\\data@I%", tex)
    @test occursin("\\newcommand\\data@I[1][all]{%", tex)
    @test occursin("\\ifnum\\pdfstrcmp{#1}{1}=0%", tex)
    @test occursin("\\ifnum\\pdfstrcmp{#1}{2}=0%", tex)

    # base=0 gives 0-based indexing
    tex0 = dumps("data", OrderedDict("arr" => [10, 20]); base = 0)
    @test occursin("\\ifnum\\pdfstrcmp{#1}{0}=0%", tex0)
    @test occursin("\\ifnum\\pdfstrcmp{#1}{1}=0%", tex0)

    # Negative numbers get {-} escape
    tex = dumps("result", OrderedDict("v" => -1.5))
    @test occursin("{-}1.5", tex)

    # Invalid name raises
    @test_throws ArgumentError dumps("bad_name", Dict())
end

@testset "dumps — list index base" begin
    v = ["x", "y", "z"]

    # default: 1-based
    tex1 = dumps("t", v)
    @test resolve_tex(tex1, "t", "1") == "x"
    @test resolve_tex(tex1, "t", "2") == "y"
    @test resolve_tex(tex1, "t", "3") == "z"
    @test resolve_tex(tex1, "t", "0") == "??"   # out of range

    # base=0: 0-based
    tex0 = dumps("t", v; base = 0)
    @test resolve_tex(tex0, "t", "0") == "x"
    @test resolve_tex(tex0, "t", "1") == "y"
    @test resolve_tex(tex0, "t", "2") == "z"
    @test resolve_tex(tex0, "t", "3") == "??"   # out of range
end

@testset "dumps — NamedTuple" begin
    tex = dumps("data", (x = "hello", y = 42))
    @test occursin("\\ifnum\\pdfstrcmp{#1}{x}=0%", tex)
    @test occursin("\\ifnum\\pdfstrcmp{#1}{y}=0%", tex)
    @test resolve_tex(tex, "data", "x") == "hello"
    @test resolve_tex(tex, "data", "y") == "42"
end

@testset "dumps — scalar top-level yields ?? for any key" begin
    # A scalar at the top level has no sub-keys; any key ≠ "all" must
    # return "??".  Tests the else-branch added to _convert_one!.
    tex = dumps("x", 42)
    @test resolve_tex(tex, "x")          == "42"
    @test resolve_tex(tex, "x", "0")     == "??"
    @test resolve_tex(tex, "x", "field") == "??"
end
