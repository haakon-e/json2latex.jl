# ---------------------------------------------------------------------------
# Roman numeral conversion  (used for sub-command naming: \name@I, \name@II …)
# ---------------------------------------------------------------------------

const _ROMAN_VALS = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
const _ROMAN_SYMS = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]

# Core implementation: write the roman numeral for n directly to io.
# n must be positive; the caller is responsible for validation.
function _write_roman!(io::IO, n::Int)
    r = n
    for (v, s) in zip(_ROMAN_VALS, _ROMAN_SYMS)
        while r >= v
            write(io, s)
            r -= v
        end
    end
end

# Public convenience wrapper — validates n and returns a String.
# Used in tests and anywhere a String is needed.
function to_roman(n::Int)
    n > 0 || throw(ArgumentError("n must be positive, got $n"))
    io = IOBuffer()
    _write_roman!(io, n)
    String(take!(io))
end

# ---------------------------------------------------------------------------
# Macro name validation and construction
# ---------------------------------------------------------------------------

# Throw ArgumentError if `name` is not a valid LaTeX command name.
# Only ASCII letters [a-zA-Z] are permitted; the TeX tokeniser does not
# recognise Unicode letters or digits as part of a command name.
function check_name(name::AbstractString)
    isempty(name) && throw(ArgumentError("LaTeX macro name must not be empty"))
    for c in name
        ('a' <= c <= 'z' || 'A' <= c <= 'Z') ||
            throw(ArgumentError("LaTeX macro name '$name' must contain only ASCII letters, got '$c'"))
    end
end

# Write \name  (ind == 0)  or  \name@I, \name@II … (ind > 0) to io.
function _write_macro_name!(io::IO, name::String, ind::Int)
    write(io, '\\', name)
    if ind > 0
        write(io, '@')
        _write_roman!(io, ind)
    end
end

# Write \name@out  or  \name@I@out … to io.
function _write_out_macro_name!(io::IO, name::String, ind::Int)
    _write_macro_name!(io, name, ind)
    write(io, "@out")
end

# ---------------------------------------------------------------------------
# TeX emitters
# ---------------------------------------------------------------------------

# Emit:  \def\name@out{%
#            <escaped, possibly multi-line value>
#        }%
#
# Single-pass implementation: iterates over the value string once, writing
# escaped characters directly to io.  Avoids the split() + per-line
# escape_latex() calls that the naive version required, eliminating ~37% of
# total allocation in dumps().
function _def_out!(io::IO, name::String, ind::Int, value)
    # Convert to string; JSON null becomes "null" rather than Julia's "nothing".
    tex_value = value isa Nothing ? "null" : string(value)
    write(io, raw"\def")
    _write_out_macro_name!(io, name, ind)
    write(io, "{%")
    at_line_start = true
    trailing_comma = false
    for c in tex_value
        if at_line_start
            print(io, "\n    ")
            at_line_start = false
            trailing_comma = false
        end
        if c == '\n'
            trailing_comma && print(io, " ")
            print(io, "%")
            at_line_start = true
        else
            write(io, get(LATEX_ESCAPES, c, c))
            trailing_comma = (c == ',')
        end
    end
    print(io, "}%")
end

# Emit:  \let\name@out\relay_macro%
function _let_out!(io::IO, name::String, ind::Int, relay::Int)
    write(io, raw"\let")
    _write_out_macro_name!(io, name, ind)
    _write_macro_name!(io, name, relay)
    write(io, "%")
end

# Emit one \ifnum\pdfstrcmp branch per key/index, with a ?? fallback.
# Nested dicts and vectors are deferred into `to_convert` and emitted as
# separate \newcommand blocks, referenced via \let.
function _add_options!(
    io::IO, name::String, ind::Int,
    pairs_iter,
    to_convert::OrderedDict{Int, Any}, index::Ref{Int},
)
    levels = 0
    for (key, value) in pairs_iter
        levels += 1
        print(io, "\\ifnum\\pdfstrcmp{#1}{$(key)}=0%")
        print(io, "\n      ")
        if value isa Union{AbstractDict, AbstractVector, NamedTuple}
            _let_out!(io, name, ind, index[])
            to_convert[index[]] = value
            index[] += 1
        else
            _def_out!(io, name, ind, value)
        end
        print(io, "\n    ")
        print(io, "\\else%")
        print(io, "\n      ")
    end
    _def_out!(io, name, ind, "??")
    print(io, "\n    ")
    print(io, "\\fi"^levels)
end

# Emit one complete \newcommand block for `obj`.
# The [all] key returns the full JSON representation; other keys dispatch
# into the object's fields/indices.  Scalars yield ?? for any key ≠ all.
function _convert_one!(
    io::IO, name::String, ind::Int, obj,
    to_convert::OrderedDict{Int, Any}, index::Ref{Int},
    base::Int = 1,
)
    write(io, raw"\newcommand")
    _write_macro_name!(io, name, ind)
    write(io, "[1][all]{%")
    print(io, "\n  ")
    print(io, "\\ifnum\\pdfstrcmp{#1}{all}=0%")
    print(io, "\n    ")
    _def_out!(io, name, ind, JSON.json(obj, 2))
    print(io, "\n  ")
    print(io, "\\else%")
    print(io, "\n    ")
    if obj isa AbstractVector
        _add_options!(io, name, ind,
            ((base + i - 1, v) for (i, v) in enumerate(obj)),
            to_convert, index)
    elseif obj isa Union{AbstractDict, NamedTuple}
        _add_options!(io, name, ind, pairs(obj), to_convert, index)
    else
        _def_out!(io, name, ind, "??")   # scalar: no sub-keys to dispatch on
    end
    print(io, "\n  ")
    print(io, "\\fi")
    print(io, "\n  ")
    _write_out_macro_name!(io, name, ind)
    print(io, "\n")
    print(io, "}")
end
