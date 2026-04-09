"""
    TexData

Make Julia data accessible directly in LaTeX documents via `\\name[key]` macros.

Supports pdfLaTeX and LuaLaTeX (`\\pdfstrcmp` is required).

# Quick start

**Write TeX directly from Julia data:**

```julia
using TexData

write_tex(Dict("title" => "My paper", "year" => 2024), "data")
# → data.tex in the current directory
```

**From a JSON file — name and output path inferred from the filename:**

```julia
write_tex("data.json")   # → data.tex, \\data
```

**Incremental merge workflow** (accumulate data across runs, regenerate TeX):

```julia
sync_tex!("data.json", Dict("version" => "2.0"))
```

!!! note
    When key order in the output must match the source JSON, pass an
    `OrderedDict` to `dumps` — it is re-exported by this package so no
    additional `using` statement is required.

See the [LaTeX integration guide](@ref) for how to use the generated `.tex` file in a document.

See also: [`dumps`](@ref), [`write_tex`](@ref), [`sync_tex!`](@ref).
"""
module TexData

import JSON
using ArgParse
using OrderedCollections: OrderedDict

export dumps, write_tex, sync_tex!, OrderedDict

include("escape.jl")
include("convert.jl")

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    dumps(obj, name) -> String

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
tex = dumps(Dict("title" => "My paper", "n" => 42), "cfg")
# \\cfg[title] → "My paper",  \\cfg[n] → "42",  \\cfg → full JSON
```

Nested structures relay to sub-commands automatically:

```julia
tex = dumps(Dict("colors" => ["red", "blue"]), "cfg")
# \\cfg[colors][1] → "red",  \\cfg[colors][2] → "blue"  (default base=1)
```
"""
function dumps(obj, name; base = 1)
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
    write_tex(name, data; tex_file = "<name>.tex", base=1)

Export `data` to a `.tex` file so it can be accessed directly in LaTeX via `\\name[key]`.

# Arguments
- `name`: Name for the LaTeX macro, e.g. `"cfg"` defines `\\cfg`, access with `\\cfg[key]`, …
- `data`: A `Dict`-like object to convert

# Keyword arguments
- `tex_file`: output path, (default: `<name>.tex`)
- `base`: start index for list elements (default: `1`).

# Examples

```julia
# From a Julia dict — name is required
write_tex("cfg", Dict("lr" => 0.001, "epochs" => 50))  # → cfg.tex
```

See the [LaTeX integration guide](@ref) for how to use the generated `.tex` file in a document.

See also: [`dumps`](@ref), [`sync_tex!`](@ref).
"""
write_tex(name, data; tex_file = "$name.tex", base = 1) =
    open(tex_file, "w") do io
        write(io, dumps(data, name; base))
    end

"""
    sync_tex!(json_file, [new_data]; [name], [tex_file], [overwrite=false], [base=1])

Merge `new_data` (if provided) into `json_file`, then generate `tex_file`.

`name` and `tex_file` are inferred from `json_file` when omitted:
`name` defaults to the filename stem; `tex_file` to the same path with a
`.tex` extension.

This is intended for **incremental update** workflows where a JSON backing
store accumulates data across multiple calls or script runs.
For direct TeX file generation without intermediate storage,
use [`write_tex`](@ref) instead.

# Arguments
- `json_file`: path to the JSON backing store.
- `new_data`: any `Dict`-like object whose entries are merged into the stored JSON.

# Keyword arguments
- `name`: LaTeX macro name (default: stem of `json_file`, without extension).
- `tex_file`: output path (default: `json_file` with `.tex` extension).
- `overwrite`: if `true`, overwrite `json_file`, if it exists (default `false`).
- `base`: base for list indexing (default: `1`).

!!! NOTE: Recursive merging of the `json_file` and `new_data` is currently not supported.

# Example

```julia
# First run: creates data.json and data.tex
sync_tex!("data.json", Dict("version" => "1.0"))

# Later run: merges new keys, updates both files
sync_tex!("data.json", Dict("accuracy" => 0.95))
```

To regenerate data.tex from data.json without updating any entires, simply call

```julia
sync_tex!(json_file)
```

See the [LaTeX integration guide](@ref) for how to use the generated `.tex` file in a document.

See [`write_tex`](@ref) for direct Dict-to-TeX conversion and 
    [`dumps`](@ref) to obtain the string that is written to tex.
"""
function sync_tex!(
    json_file,
    new_data = OrderedDict();
    name = _name_from_json(json_file),
    tex_file = _tex_from_json(json_file),
    overwrite = false,
    base = 1,
)
    # TODO: Add NamedTuple support
    # TODO: Add recursive merge!
    T = OrderedDict{String, Any}
    current = (!overwrite && isfile(json_file)) ?
              JSON.parsefile(json_file; dicttype = OrderedDict) : T()
    merge!(current, T(new_data))
    if !overwrite && isempty(current)
        json_str = isfile(json_file) ? "Set `overwrite=true` to clear existing JSON/TeX file" : ""
        @warn "No data to write. $json_str"
        return nothing
    end
    !isempty(new_data) && open(json_file, "w") do io
        JSON.print(io, current, 2)
    end
    write_tex(name, current; tex_file, base)
end

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

function parse_commandline()
    s = ArgParseSettings(
        prog = "texdata",
        description = "Convert a JSON file into LaTeX macro definitions. \n
                       Use \\<name>[key] to access individual fields.",
        version = string(pkgversion(TexData)),
    )
    @add_arg_table! s begin
        "input"
        help = "path to the input JSON file"
        required = true
        "--name", "-n"
        help = "LaTeX command name, ASCII letters only \n
                (default: filename stem of input)"
        metavar = "NAME"
        "--output", "-o"
        help = "output path for the generated .tex file \n
                (default: input with .tex extension)"
        metavar = "PATH"
        "--base", "-b"
        help = "starting index for list elements"
        metavar = "N"
        arg_type = Integer
        default = 1
        "--version", "-v"
        action = :show_version
        help = "show version and exit"
    end
    s
end

function (@main)(ARGS)
    args = parse_args(ARGS, parse_commandline())
    isnothing(args) && return 0

    json_file = args["input"]
    name = something(args["name"], _name_from_json(json_file))
    kw = filter(p -> !isnothing(p.second), [
        :tex_file => args["output"],
        :base => args["base"],
    ])

    try
        data = JSON.parsefile(json_file; dicttype = OrderedDict)
        write_tex(name, data; kw...)
    catch e
        print(stderr, "Error: ")
        showerror(stderr, e)
        println(stderr)
        return 1
    end
    return 0
end

end # module TexData
