module json2latex

using JSON
using OrderedCollections

export dumps, dump_tex, update_and_generate_tex, escape_latex, to_roman, check_name

# ---------------------------------------------------------------------------
# LaTeX character escaping (mirrors json2latex/escape.py)
# ---------------------------------------------------------------------------

const LATEX_ESCAPES = Dict{Char,String}(
    '&'      => "\\&",
    '%'      => "\\%",
    '$'      => "\\\$",
    '#'      => "\\#",
    '_'      => "\\_",
    '{'      => "\\{",
    '}'      => "\\}",
    '~'      => "\\textasciitilde{}",
    '^'      => "\\^{}",
    '\\'     => "\\textbackslash{}",
    '\n'     => "\\newline%\n",
    '-'      => "{-}",
    '\u00A0' => "~",
    '['      => "{[}",
    ']'      => "{]}",
)

function escape_latex(s::AbstractString)
    io = IOBuffer()
    for c in s
        write(io, get(LATEX_ESCAPES, c, string(c)))
    end
    String(take!(io))
end

# ---------------------------------------------------------------------------
# Roman numeral conversion (needed for sub-command naming)
# ---------------------------------------------------------------------------

const _ROMAN_VALS = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
const _ROMAN_SYMS = ["M","CM","D","CD","C","XC","L","XL","X","IX","V","IV","I"]

function to_roman(n::Int)
    n > 0 || throw(ArgumentError("n must be positive, got $n"))
    buf = IOBuffer()
    rem = n
    for (v, s) in zip(_ROMAN_VALS, _ROMAN_SYMS)
        while rem >= v
            write(buf, s)
            rem -= v
        end
    end
    String(take!(buf))
end

# ---------------------------------------------------------------------------
# Macro name helpers
# ---------------------------------------------------------------------------

function check_name(name::AbstractString)
    isempty(name) && throw(ArgumentError("LaTeX macro name must not be empty"))
    for c in name
        (isuppercase(c) || islowercase(c)) ||
            throw(ArgumentError("LaTeX macro name '$name' must contain only letters, got '$c'"))
    end
end

_macro_name(name::String, ind::Int) =
    ind > 0 ? "\\$(name)@$(to_roman(ind))" : "\\$(name)"

_out_macro_name(name::String, ind::Int) = _macro_name(name, ind) * "@out"

# ---------------------------------------------------------------------------
# Scalar value → string
# Mirrors Python's str() for common types; booleans use lowercase (JSON standard)
# ---------------------------------------------------------------------------

_scalar_str(v::AbstractString) = v
_scalar_str(v::Bool)           = string(v)          # "true" / "false"
_scalar_str(v::Integer)        = string(v)
_scalar_str(v::AbstractFloat)  = string(v)
_scalar_str(::Nothing)         = "null"
_scalar_str(v)                 = string(v)

# ---------------------------------------------------------------------------
# \def\name@out{%  ...multiline value...  }%
# ---------------------------------------------------------------------------

function _def_out!(io::IO, name::String, ind::Int, value)
    tex_value = _scalar_str(value)
    print(io, "\\def$(_out_macro_name(name, ind)){%")
    parts = split(tex_value, "\n")
    for (i, part) in enumerate(parts)
        print(io, "\n    ")                      # _nl(indent=2) = 4 spaces
        print(io, escape_latex(part))
        if i < length(parts)
            endswith(part, ",") && print(io, " ")
            print(io, "%")
        end
    end
    print(io, "}%")
end

# \let\name@out\relay_macro%
function _let_out!(io::IO, name::String, ind::Int, relay::Int)
    print(io, "\\let$(_out_macro_name(name, ind))$(_macro_name(name, relay))%")
end

# ---------------------------------------------------------------------------
# Add key branches: one \ifnum\pdfstrcmp per key, ?? fallback
# ---------------------------------------------------------------------------

function _add_options!(io::IO, name::String, ind::Int,
                       pairs_iter,
                       to_convert::OrderedDict{Int,Any}, index::Ref{Int})
    levels = 0
    for (key, value) in pairs_iter
        levels += 1
        print(io, "\\ifnum\\pdfstrcmp{#1}{$(key)}=0%")
        print(io, "\n      ")                    # _nl(indent=3)
        if value isa Union{AbstractDict, AbstractVector}
            _let_out!(io, name, ind, index[])
            to_convert[index[]] = value
            index[] += 1
        else
            _def_out!(io, name, ind, value)
        end
        print(io, "\n    ")                      # _nl(indent=2)
        print(io, "\\else%")
        print(io, "\n      ")                    # _nl(indent=3)
    end
    _def_out!(io, name, ind, "??")
    print(io, "\n    ")                          # _nl(indent=2)
    print(io, "\\fi" ^ levels)
end

# ---------------------------------------------------------------------------
# Single \newcommand block
# ---------------------------------------------------------------------------

function _convert_one!(io::IO, name::String, ind::Int, obj,
                       to_convert::OrderedDict{Int,Any}, index::Ref{Int})
    print(io, "\\newcommand$(_macro_name(name, ind))[1][all]{%")
    print(io, "\n  ")                            # _nl(indent=1)
    print(io, "\\ifnum\\pdfstrcmp{#1}{all}=0%")
    print(io, "\n    ")                          # _nl(indent=2)
    _def_out!(io, name, ind, JSON.json(obj, 2))
    print(io, "\n  ")                            # _nl(indent=1)
    print(io, "\\else%")
    print(io, "\n    ")                          # _nl(indent=2)
    if obj isa AbstractVector
        _add_options!(io, name, ind,
                      ((i - 1, v) for (i, v) in enumerate(obj)),
                      to_convert, index)
    elseif obj isa AbstractDict
        _add_options!(io, name, ind, pairs(obj), to_convert, index)
    end
    print(io, "\n  ")                            # _nl(indent=1)
    print(io, "\\fi")
    print(io, "\n  ")                            # _nl(indent=1)
    print(io, _out_macro_name(name, ind))
    print(io, "\n")                              # _nl(indent=0)
    print(io, "}")
end

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

"""
    dumps(name, obj) -> String

Convert a nested Julia structure (Dict/Vector/scalar) to a LaTeX string.
The result defines `\\name[key][subkey]...` macros.

`name` must be letters only (valid LaTeX macro name).
"""
function dumps(name::AbstractString, obj)
    check_name(name)
    sname = String(name)
    io = IOBuffer()
    print(io, "\\makeatletter%\n")
    to_convert = OrderedDict{Int,Any}(0 => obj)
    index = Ref(1)
    while !isempty(to_convert)
        ind = first(keys(to_convert))
        current = to_convert[ind]
        delete!(to_convert, ind)
        _convert_one!(io, sname, ind, current, to_convert, index)
    end
    print(io, "%\n\\makeatother%")
    String(take!(io))
end

"""
    dump_tex(name, obj, fp)

Write the LaTeX commands for `obj` to the IO stream `fp`.
"""
function dump_tex(name::AbstractString, obj, fp::IO)
    write(fp, dumps(name, obj))
end

# ---------------------------------------------------------------------------
# Update workflow (replaces write_data_to_tex.jl / PythonCall version)
# ---------------------------------------------------------------------------

"""
    update_and_generate_tex(new_data; json_file, tex_file, command_name, overwrite)

Merge `new_data` into an existing JSON file, then regenerate the TeX file.
Equivalent to the old `update_and_generate_tex` from `write_data_to_tex.jl`
but without any Python dependency.
"""
function update_and_generate_tex(new_data;
        json_file    = "data.json",
        tex_file     = "data.tex",
        command_name = "data",
        overwrite    = false)
    T = OrderedDict{String,Any}
    current = (!overwrite && isfile(json_file)) ?
              JSON.parsefile(json_file; dicttype=OrderedDict) : T()
    merge!(current, T(new_data))
    open(json_file, "w") do io
        JSON.print(io, current, 2)
    end
    open(tex_file, "w") do io
        dump_tex(command_name, current, io)
    end
    nothing
end

# ---------------------------------------------------------------------------
# CLI entry point:  json2latex <input.json> <name> <output.tex>
# ---------------------------------------------------------------------------

function (@main)(ARGS)
    if length(ARGS) != 3
        println(stderr, "Usage: json2latex <input.json> <name> <output.tex>")
        return 1
    end
    input_json, name, output_tex = ARGS
    if !isfile(input_json)
        println(stderr, "File not found: $input_json")
        return 1
    end
    try
        obj = JSON.parsefile(input_json; dicttype=OrderedDict)
        open(output_tex, "w") do io
            dump_tex(name, obj, io)
        end
    catch e
        println(stderr, "Error: $e")
        return 1
    end
    return 0
end

end # module
