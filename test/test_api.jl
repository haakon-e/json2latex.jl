@testset "generate_tex" begin
    mktempdir() do dir
        json = joinpath(@__DIR__, "test.json")

        # explicit name and output path
        dest = joinpath(dir, "out.tex")
        generate_tex(json; name = "data", tex_file = dest)
        @test isfile(dest)
        @test read(dest, String) == TEX   # must match dumps output for same input

        # explicit name only — tex_file inferred from json path
        cp(json, joinpath(dir, "mydata.json"))
        generate_tex(joinpath(dir, "mydata.json"); name = "mydata")
        inferred_tex = joinpath(dir, "mydata.tex")
        @test isfile(inferred_tex)
        @test occursin("\\mydata", read(inferred_tex, String))

        # both inferred from filename
        cp(json, joinpath(dir, "other.json"))
        generate_tex(joinpath(dir, "other.json"))
        @test isfile(joinpath(dir, "other.tex"))
        inferred = read(joinpath(dir, "other.tex"), String)
        @test startswith(inferred, "\\makeatletter")
        @test occursin("\\other", inferred)
    end
end

@testset "golden output" begin
    # Compare against a committed fixture to catch format regressions.
    # On the first run the fixture is written automatically; verify its
    # content and commit it so subsequent runs are meaningful.
    fixture = joinpath(@__DIR__, "golden.tex")
    if isfile(fixture)
        @test TEX == read(fixture, String)
    else
        write(fixture, TEX)
        @warn "No golden fixture found — wrote $fixture. " *
              "Verify its content and commit it."
    end
end
