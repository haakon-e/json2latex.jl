"""
    json2latex

Convert JSON/Julia data structures into self-contained LaTeX macro definitions.

The generated macros support optional key arguments for field access and work
with pdfLaTeX and LuaLaTeX (`\\pdfstrcmp` is required).

# Quick start

**From a Julia `Dict` — no extra packages needed:**

```julia
using json2latex

tex = dumps("data", Dict("title" => "My paper", "year" => 2024))
write("data.tex", tex)
# \\data[title] → "My paper",  \\data[year] → "2024",  \\data → full JSON
```

**From a JSON file — name and output path inferred from the filename:**

```julia
generate_tex("data.json")                               # → data.tex, \\data
generate_tex("data.json"; tex_file = "build/data.tex")  # custom output path
```

**Incremental merge workflow** (accumulate data across runs, regenerate TeX):

```julia
generate_tex!("data.json", Dict("version" => "2.0"))
```

!!! note
    When key order in the output must match the source JSON, pass an
    `OrderedDict` to `dumps` — it is re-exported by this package so no
    additional `using` statement is required.  `generate_tex` and
    `generate_tex!` always preserve order automatically.

See also: [`dumps`](@ref), [`generate_tex`](@ref), [`generate_tex!`](@ref).
"""
module json2latex

import JSON
using ArgParse
using OrderedCollections: OrderedDict

export dumps, generate_tex, generate_tex!, OrderedDict

include("escape.jl")
include("convert.jl")

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    dumps(name, obj) -> String

Convert a nested Julia structure (`Dict`, `Vector`, `NamedTuple`, or scalar)
into a string of LaTeX commands that define `\\name`, `\\name[key]`,
`\\name[key][sub]`, …

`name` must contain only ASCII letters (e.g. `"data"`, `"cfg"`).
The generated macros require `\\pdfstrcmp` (available in pdfLaTeX and LuaLaTeX).

The `base` keyword controls list indexing: `base=1` (the default) makes the
first element `\\name[1]`; `base=0` gives 0-based indexing.

!!! note
    A plain `Dict` works but produces non-deterministic key order.
    Use `OrderedDict` when order matters — it is re-exported by this package.

# Examples

```julia
tex = dumps("cfg", Dict("title" => "My paper", "n" => 42))
# \\cfg[title] → "My paper",  \\cfg[n] → "42",  \\cfg → full JSON
```

Nested structures relay to sub-commands automatically:

```julia
tex = dumps("cfg", Dict("colors" => ["red", "blue"]))
# \\cfg[colors][1] → "red",  \\cfg[colors][2] → "blue"  (default base=1)
```
"""
function dumps(name::AbstractString, obj; base::Int = 1)
    check_name(name)
    sname = String(name)
    io = IOBuffer()
    print(io, "\\makeatletter%\n")
    to_convert = OrderedDict{Int, Any}(0 => obj)
    index = Ref(1)
    while !isempty(to_convert)
        ind, current = popfirst!(to_convert)
        _convert_one!(io, sname, ind, current, to_convert, index, base)
    end
    print(io, "%\n\\makeatother%")
    String(take!(io))
end

# Infer the LaTeX command name and .tex output path from a JSON file path.
_name_from_json(json_file) = splitext(basename(json_file))[1]
_tex_from_json(json_file) = splitext(json_file)[1] * ".tex"

"""
    generate_tex(json_file; name, tex_file)

Read `json_file` and write LaTeX macro definitions to `tex_file`, using
`name` as the command name.  Both `name` and `tex_file` are inferred from
`json_file` when omitted:

- `name` defaults to the filename stem (e.g. `"data"` from `"data.json"`).
- `tex_file` defaults to `json_file` with the extension replaced by `.tex`,
  placing the output next to the source JSON.

Key order from the source JSON is always preserved.

# Examples

```julia
using json2latex
generate_tex("data.json")  # → data.tex, \\data
generate_tex("inputs/data.json"; tex_file="build/data.tex")
```

See also: [`dumps`](@ref), [`generate_tex!`](@ref).
"""
function generate_tex(json_file;
    name     = _name_from_json(json_file),
    tex_file = _tex_from_json(json_file),
    base::Int = 1,
)
    obj = JSON.parsefile(json_file; dicttype = OrderedDict)
    open(tex_file, "w") do io
        write(io, dumps(name, obj; base))
    end
    nothing
end

"""
    generate_tex!(json_file, new_data; name, tex_file, overwrite)

Merge `new_data` into `json_file`, then regenerate `tex_file` with
[`dumps`](@ref).  If `json_file` does not yet exist (or `overwrite=true`)
it is created from scratch.

`name` and `tex_file` are inferred from `json_file` when omitted (see
[`generate_tex`](@ref) for the inference rules).

This is intended for **incremental update** workflows where a JSON backing
store accumulates data across multiple script runs.  For one-shot file
conversion use [`generate_tex`](@ref) instead.

# Arguments
- `json_file`: path to the JSON backing store.
- `new_data`: any `Dict`-like object whose entries are merged into the stored JSON.

# Keyword arguments
- `name`: LaTeX macro name (default: stem of `json_file`).
- `tex_file`: output path (default: `json_file` with `.tex` extension).
- `overwrite`: if `true`, ignore any existing `json_file` (default `false`).

# Example

```julia
# First run: creates data.json and data.tex
generate_tex!("data.json", Dict("version" => "1.0"))

# Later run: merges new keys, regenerates both files
generate_tex!("data.json", Dict("accuracy" => 0.95))
```
"""
function generate_tex!(
    json_file,
    new_data;
    name      = _name_from_json(json_file),
    tex_file  = _tex_from_json(json_file),
    overwrite = false,
    base::Int = 1,
)
    T = OrderedDict{String, Any}
    current = (!overwrite && isfile(json_file)) ?
              JSON.parsefile(json_file; dicttype = OrderedDict) : T()
    merge!(current, T(new_data))
    open(json_file, "w") do io
        JSON.print(io, current, 2)
    end
    open(tex_file, "w") do io
        write(io, dumps(name, current; base))
    end
    nothing
end

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

function parse_commandline()
    s = ArgParseSettings(
        prog        = "json2latex",
        description = "Convert a JSON file into LaTeX macro definitions.\n\n\
                       The generated macros are compatible with pdfLaTeX and LuaLaTeX. \
                       Use \\<name>[key] to access individual fields, \
                       \\<name> for the full JSON.",
        version     = string(pkgversion(json2latex)),
    )
    @add_arg_table! s begin
        "input"
            help     = "path to the input JSON file"
            required = true
        "--name", "-n"
            help    = "LaTeX command name, ASCII letters only \
                       (default: filename stem of input)"
            metavar = "NAME"
        "--output", "-o"
            help    = "output path for the generated .tex file \
                       (default: input with .tex extension)"
            metavar = "PATH"
        "--base", "-b"
            help    = "starting index for list elements (default: 1)"
            metavar = "N"
            arg_type = Int
            default  = 1
        "--version", "-v"
            action  = :show_version
            help    = "show version and exit"
    end
    s
end

function (@main)(ARGS)
    args = parse_args(ARGS, parse_commandline())
    isnothing(args) && return 0

    kw = filter(p -> !isnothing(p.second), [
        :name     => args["name"],
        :tex_file => args["output"],
        :base     => args["base"],
    ])

    try
        generate_tex(args["input"]; kw...)
    catch e
        print(stderr, "Error: ")
        showerror(stderr, e)
        println(stderr)
        return 1
    end
    return 0
end

end # module json2latex
