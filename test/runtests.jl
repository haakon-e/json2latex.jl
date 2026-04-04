using Test
using JSON
using OrderedCollections

# Load the module under test directly (avoids needing Pkg.test infrastructure)
include(joinpath(@__DIR__, "..", "src", "json2latex.jl"))
import .json2latex: dumps, dump_tex, escape_latex, to_roman, check_name

# ---------------------------------------------------------------------------
# TeX macro resolver for integration tests
# Simulates \cmd[k1][k2]... expansion on the generated TeX string.
# ---------------------------------------------------------------------------

# Find the closing } of a \def{...} block using brace-depth tracking.
# We enter at depth=1 (already inside the opening {).
# Characters after \ are skipped (they belong to TeX escape sequences and
# must not affect depth), so \{ and \} are ignored, while {-}, {[}, {]}
# and \^{}, \textbackslash{} etc. are correctly handled as balanced pairs.
function _find_close_def(s::AbstractString, start::Int)
    depth = 1
    i = start
    while i <= lastindex(s)
        c = s[i]
        if c == '\\'
            i = nextind(s, i)          # skip the escaped character
        elseif c == '{'
            depth += 1
        elseif c == '}'
            depth -= 1
            depth == 0 && return i
        end
        i = nextind(s, i)
    end
    return nothing
end

# Extract the unescaped scalar string from a \def block's content.
# The content is the raw TeX between {%\n and }% (the lines with 4-space indent).
function _extract_def_content(raw::AbstractString)
    lines = split(raw, "\n")
    result = String[]
    for line in lines
        # Strip the 4-space indent added by _def_out!
        stripped = startswith(line, "    ") ? line[5:end] : line
        # Strip trailing " %" or "%" (continuation markers on non-last lines)
        stripped = replace(stripped, r" ?%$" => "")
        push!(result, stripped)
    end
    # Unescape LaTeX special characters back to original
    s = join(result, "\n")
    s = replace(s, "\\&"  => "&")
    s = replace(s, "\\%"  => "%")
    s = replace(s, "\\\$" => "\$")
    s = replace(s, "\\#"  => "#")
    s = replace(s, "\\_"  => "_")
    s = replace(s, "\\{"  => "{")
    s = replace(s, "\\}"  => "}")
    s = replace(s, "\\textasciitilde{}" => "~")
    s = replace(s, "\\^{}" => "^")
    s = replace(s, "\\textbackslash{}" => "\\")
    s = replace(s, "\\newline%\n" => "\n")
    s = replace(s, "{-}"  => "-")
    s = replace(s, "~"    => "\u00A0")   # non-breaking space (rare)
    s = replace(s, "{[}"  => "[")
    s = replace(s, "{]}"  => "]")
    s
end

# Resolve \CMD[keys...] in a generated TeX string.
# Returns the scalar string value, or "??" for missing keys.
# Pass no keys to get the "all" (full JSON) value.
function resolve_tex(tex::AbstractString, cmd::AbstractString, keys::AbstractString...)
    current_cmd = String(cmd)
    for key in keys
        # Locate command definition header
        header = "\\newcommand\\$(current_cmd)[1][all]{%"
        hpos = findfirst(header, tex)
        isnothing(hpos) && return "??"
        search_start = last(hpos) + 1

        # Boundary: next \newcommand (or end of string)
        next_cmd_pos = findnext("\\newcommand\\", tex, search_start)
        block_end = isnothing(next_cmd_pos) ? lastindex(tex) : first(next_cmd_pos) - 1

        block = SubString(tex, search_start, block_end)

        # Find the key branch
        key_str = "\\ifnum\\pdfstrcmp{#1}{$(key)}=0%\n      "
        kpos = findfirst(key_str, block)
        isnothing(kpos) && return "??"

        after_key = last(kpos) + 1
        rest = SubString(block, after_key)

        if startswith(rest, "\\let")
            # \let\CMD@out\RELAY_CMD%  — relay to another command
            nl = findfirst('\n', rest)
            line = isnothing(nl) ? String(rest) : String(rest[1:nl-1])
            line = rstrip(line, '%')
            bp = findlast('\\', line)
            isnothing(bp) && return "??"
            current_cmd = line[bp+1:end]
        elseif startswith(rest, "\\def")
            # \def\CMD@out{%\n    VALUE...}%
            open_pos = findfirst("{%\n", rest)
            isnothing(open_pos) && return "??"
            content_start = last(open_pos) + 1
            close_idx = _find_close_def(String(rest), content_start)
            isnothing(close_idx) && return "??"
            raw = String(rest)[content_start:close_idx-1]
            return _extract_def_content(raw)
        else
            return "??"
        end
    end

    # No more keys (either original call had no keys, or we followed relays to end)
    # Return the "all" value for current_cmd
    header = "\\newcommand\\$(current_cmd)[1][all]{%"
    hpos = findfirst(header, tex)
    isnothing(hpos) && return "??"
    search_start = last(hpos) + 1
    all_key_str = "\\ifnum\\pdfstrcmp{#1}{all}=0%\n    "
    apos = findnext(all_key_str, tex, search_start)
    isnothing(apos) && return "??"
    after_all = last(apos) + 1
    rest = SubString(tex, after_all)
    startswith(rest, "\\def") || return "??"
    open_pos = findfirst("{%\n", rest)
    isnothing(open_pos) && return "??"
    content_start = last(open_pos) + 1
    close_idx = _find_close_def(String(rest), content_start)
    isnothing(close_idx) && return "??"
    raw = String(rest)[content_start:close_idx-1]
    return _extract_def_content(raw)
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@testset "json2latex" begin

    @testset "escape_latex" begin
        @test escape_latex("hello") == "hello"
        @test escape_latex("&") == "\\&"
        @test escape_latex("%") == "\\%"
        @test escape_latex("\$") == "\\\$"
        @test escape_latex("#") == "\\#"
        @test escape_latex("_") == "\\_"
        @test escape_latex("{") == "\\{"
        @test escape_latex("}") == "\\}"
        @test escape_latex("~") == "\\textasciitilde{}"
        @test escape_latex("^") == "\\^{}"
        @test escape_latex("\\") == "\\textbackslash{}"
        @test escape_latex("-") == "{-}"
        @test escape_latex("[") == "{[}"
        @test escape_latex("]") == "{]}"
        @test escape_latex("\u00A0") == "~"
        # Combined
        @test escape_latex("a-b") == "a{-}b"
        @test escape_latex("x_y") == "x\\_y"
    end

    @testset "to_roman" begin
        @test to_roman(1)  == "I"
        @test to_roman(2)  == "II"
        @test to_roman(3)  == "III"
        @test to_roman(4)  == "IV"
        @test to_roman(5)  == "V"
        @test to_roman(9)  == "IX"
        @test to_roman(10) == "X"
        @test to_roman(14) == "XIV"
        @test to_roman(40) == "XL"
        @test to_roman(400) == "CD"
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
    end

    @testset "dumps structure" begin
        # Boilerplate wrapping
        tex = dumps("data", OrderedDict("x" => 1))
        @test startswith(tex, "\\makeatletter%\n")
        @test endswith(tex, "%\n\\makeatother%")
        @test occursin("\\newcommand\\data[1][all]{%", tex)

        # Single scalar key
        tex = dumps("data", OrderedDict("foo" => 42))
        @test occursin("\\ifnum\\pdfstrcmp{#1}{foo}=0%", tex)
        @test occursin("42", tex)

        # Missing key fallback
        @test occursin("??", tex)

        # Nested: list relays to a sub-command
        tex = dumps("data", OrderedDict("arr" => [10, 20]))
        @test occursin("\\let\\data@out\\data@I%", tex)
        @test occursin("\\newcommand\\data@I[1][all]{%", tex)
        @test occursin("\\ifnum\\pdfstrcmp{#1}{0}=0%", tex)
        @test occursin("\\ifnum\\pdfstrcmp{#1}{1}=0%", tex)

        # Negative numbers get {-} escape
        tex = dumps("result", OrderedDict("v" => -1.5))
        @test occursin("{-}1.5", tex)

        # Invalid name raises
        @test_throws ArgumentError dumps("bad_name", Dict())
    end

    # Load the reference test fixture (same data as the upstream json2latex test suite)
    test_json = JSON.parsefile(
        joinpath(@__DIR__, "test.json");
        dicttype = OrderedDict,
    )
    tex = dumps("data", test_json)

    @testset "flat scalar keys" begin
        @test resolve_tex(tex, "data", "baz") == "test"
        @test resolve_tex(tex, "data", "bar") == "true"   # Julia bool → "true"
    end

    @testset "list access" begin
        @test resolve_tex(tex, "data", "foo", "0") == "0.1"
        @test resolve_tex(tex, "data", "foo", "1") == "3"
    end

    @testset "missing key returns ??" begin
        @test resolve_tex(tex, "data", "foo", "2")       == "??"
        @test resolve_tex(tex, "data", "not")             == "??"
        @test resolve_tex(tex, "data", "blah", "2")       == "??"
        @test resolve_tex(tex, "data", "blah", "1", "not") == "??"
        @test resolve_tex(tex, "data", "blah", "0", "not") == "??"
        @test resolve_tex(tex, "data", "blah", "1", "g", "3") == "??"
    end

    @testset "nested dict access" begin
        @test resolve_tex(tex, "data", "blah", "0", "a")    == "b"
        @test resolve_tex(tex, "data", "blah", "0", "test") == "3.1415"
        @test resolve_tex(tex, "data", "blah", "1", "c")    == "f"
    end

    @testset "deeply nested list" begin
        @test resolve_tex(tex, "data", "blah", "1", "g", "0") == "x"
        @test resolve_tex(tex, "data", "blah", "1", "g", "1") == "yz"
        @test resolve_tex(tex, "data", "blah", "1", "g", "2") == "101"
    end

    @testset "all (full JSON) display" begin
        # The "all" value for a list/dict should round-trip through JSON.
        # (The Python test suite checks no comma-then-non-space in the *rendered*
        # LaTeX output; we verify correctness by round-tripping through the JSON parser.)
        foo_all = resolve_tex(tex, "data", "foo")
        @test JSON.parse(foo_all) == [0.1, 3]

        blah0_all = resolve_tex(tex, "data", "blah", "0")
        parsed = JSON.parse(blah0_all)
        @test parsed["a"] == "b"
        @test parsed["test"] == 3.1415

        g_all = resolve_tex(tex, "data", "blah", "1", "g")
        @test JSON.parse(g_all) == ["x", "yz", 101]

        # Top-level "all" also round-trips
        top_all = resolve_tex(tex, "data")
        parsed_top = JSON.parse(top_all)
        @test parsed_top["baz"] == "test"
        @test parsed_top["foo"] == [0.1, 3]
    end

    @testset "dump_tex writes to IO" begin
        buf = IOBuffer()
        dump_tex("result", OrderedDict("n" => 99), buf)
        s = String(take!(buf))
        @test occursin("\\newcommand\\result", s)
        @test occursin("99", s)
    end

end
