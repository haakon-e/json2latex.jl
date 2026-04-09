# Performance / allocation regression tests for the top-level API.
#
# Timing: minimum over N runs after a JIT warm-up call.  Taking the minimum
# rather than the mean suppresses OS scheduling noise and gives a stable
# lower-bound on wall-clock cost.  Ceilings are set at ~20× the observed
# minimum so that the checks pass comfortably on slow CI machines while
# still catching any order-of-magnitude regression.
#
# Allocation: single post-warm-up call; ceiling is ~50% above observed.
#
# Observed baselines (reference machine: aarch64 macOS, Julia 1.12):
#   dumps  small fixture  (TEST_JSON, 4 keys + nested)   ≈   26 µs,  22 kB
#   dumps  large fixture  (~11 top-level keys, deeper)   ≈  115 µs,  78 kB
#   file_to_tex (read JSON + dumps + write, test.json)   ≈   93 µs,  26 kB
#
# If you intentionally change the output format or algorithm, re-measure and
# update both columns; don't just raise the ceilings to silence a failure.

# Shared large fixture used by both testsets.
const _PERF_LARGE = OrderedDict{String,Any}(
    "title"      => "Performance test document",
    "version"    => "1.0.0",
    "enabled"    => true,
    "count"      => 42,
    "ratio"      => 3.14159,
    "tags"       => ["julia", "latex", "json", "performance", "testing"],
    "author"     => OrderedDict{String,Any}(
                        "name"  => "Test Author",
                        "email" => "test@example.com"),
    "items"      => [OrderedDict{String,Any}(
                        "id"     => i,
                        "value"  => "item_$i",
                        "active" => iseven(i)) for i in 1:8],
    "meta"       => OrderedDict{String,Any}(
                        "created" => "2024-01-01",
                        "updated" => "2024-06-15",
                        "notes"   => "50% off & save \$10"),
    "empty_list" => [],
    "nested"     => OrderedDict{String,Any}(
                        "a" => OrderedDict{String,Any}(
                                   "b" => OrderedDict{String,Any}("c" => "deep"))),
)

@testset "dumps — timing" begin
    N = 10   # runs for minimum; keeps test fast while suppressing noise

    # small fixture
    dumps(TEST_JSON, "data")   # JIT warm-up
    t_small = minimum(@elapsed(dumps(TEST_JSON, "data")) for _ in 1:N)
    @test t_small < 1e-3       # < 1 ms  (observed ≈ 26 µs)

    # large fixture
    dumps(_PERF_LARGE, "bench")   # JIT warm-up
    t_large = minimum(@elapsed(dumps(_PERF_LARGE, "bench")) for _ in 1:N)
    @test t_large < 5e-3           # < 5 ms  (observed ≈ 115 µs)
end

@testset "dumps — allocation budget" begin
    dumps(TEST_JSON, "data")                            # JIT warm-up
    @test @allocated(dumps(TEST_JSON, "data")) < 35_000    # observed ≈ 22 kB

    dumps(_PERF_LARGE, "bench")                         # JIT warm-up
    @test @allocated(dumps(_PERF_LARGE, "bench")) < 120_000   # observed ≈ 78 kB
end

@testset "sync_tex! (JSON) — timing and allocation budget" begin
    N = 10
    json = joinpath(@__DIR__, "test.json")

    mktempdir() do dir
        out = joinpath(dir, "out.tex")

        sync_tex!(json; tex_file = out)   # JIT warm-up

        t = minimum(@elapsed(sync_tex!(json; tex_file = out)) for _ in 1:N)
        @test t < 2e-3   # < 2 ms  (observed ≈ 93 µs; includes JSON parse + write)

        @test @allocated(sync_tex!(json; tex_file = out)) < 40_000   # observed ≈ 30 kB
    end
end
