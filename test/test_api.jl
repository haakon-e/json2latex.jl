@testset "write_tex" begin
    mktempdir() do dir
        data = OrderedDict("x" => 1, "y" => "hello")

        # explicit tex_file
        dest = joinpath(dir, "out.tex")
        write_tex("t", data; tex_file = dest)
        @test isfile(dest)
        @test read(dest, String) == dumps(data, "t")

        # tex_file inferred from name
        dest2 = joinpath(dir, "myname.tex")
        write_tex("myname", data; tex_file = dest2)
        @test isfile(dest2)
        @test occursin("\\myname", read(dest2, String))

    end
end

@testset "write_tex — from JSON file" begin
    mktempdir() do dir
        json = joinpath(@__DIR__, "test.json")

        # explicit name and output path
        dest = joinpath(dir, "out.tex")
        sync_tex!(json; name = "data", tex_file = dest)
        @test isfile(dest)
        @test read(dest, String) == TEX

        # explicit name only — tex_file inferred from json path
        cp(json, joinpath(dir, "mydata.json"))
        sync_tex!(joinpath(dir, "mydata.json"))
        @test isfile(joinpath(dir, "mydata.tex"))
        @test occursin("\\mydata", read(joinpath(dir, "mydata.tex"), String))

        # both inferred from filename
        cp(json, joinpath(dir, "other.json"))
        sync_tex!(joinpath(dir, "other.json"))
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
