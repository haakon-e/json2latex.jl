# ---------------------------------------------------------------------------
# Roman numeral conversion  (used for sub-command naming: \name@I, \name@II …)
# ---------------------------------------------------------------------------

const _ROMAN_VALS = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
const _ROMAN_SYMS = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]

function to_roman!(io, n)
    n > 0 || throw(ArgumentError("n must be positive, got $n"))
    r = n
    for (v, s) in zip(_ROMAN_VALS, _ROMAN_SYMS)
        while r >= v
            write(io, s)
            r -= v
        end
    end
end

function to_roman(n)
    io = IOBuffer()
    to_roman!(io, n)
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
function _write_macro_name!(io, name, ind)
    write(io, '\\', name)
    if ind > 0
        write(io, '@')
        to_roman!(io, ind)
    end
end

# Write \name@out  or  \name@I@out … to io.
function _write_out_macro_name!(io, name, ind)
    _write_macro_name!(io, name, ind)
    write(io, "@out")
end

# ---------------------------------------------------------------------------
# TeX emitters
# ---------------------------------------------------------------------------

# Define the output macro that holds a single scalar value, LaTeX-escaped:
#
#   \def\name@out{%
#       <escaped value>
#   }%
#
# Iterates character by character: (1) to apply LATEX_ESCAPES substitutions,
# (2) to convert \n to %\n (TeX line comment) with indentation. trailing_comma
# inserts a space before % after a comma, which some engines misparse otherwise.
function _def_out!(io, name, ind, value)
    tex_value = string(value)
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

# Like _def_out! but aliases the output macro to an already-defined sub-command
# (used for nested objects whose \newcommand block is emitted separately):
#
#   \let\name@out\name@I%
#
function _let_out!(io, name, ind, relay)
    write(io, raw"\let")
    _write_out_macro_name!(io, name, ind)
    _write_macro_name!(io, name, relay)
    write(io, "%")
end

# Emit the key-dispatch body used inside a \newcommand: one \pdfstrcmp branch
# per key/index, falling back to ??. Scalars use _def_out!; nested objects are
# deferred into to_convert and referenced via _let_out!:
#
#   \ifnum\pdfstrcmp{#1}{key}=0%  _def_out! or _let_out!
#   \else%
#     ...
#   \fi\fi...
#
function _add_options!(io, name, ind, pairs_iter, to_convert, index)
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

# Emit one complete \newcommand block for obj. The [all] key returns the full
# JSON; other keys dispatch via _add_options!. Scalars yield ?? for any key ≠ all:
#
#   \newcommand\name[1][all]{%
#     \ifnum\pdfstrcmp{#1}{all}=0%  _def_out!(JSON)
#     \else%                         _add_options! (or ?? for scalars)
#     \fi
#     \name@out
#   }
#
function _convert_one!(io, name, ind, obj, to_convert, index, base = 1)
    write(io, raw"\newcommand")
    _write_macro_name!(io, name, ind)
    write(io, "[1][all]{%")
    print(io, "\n  ")
    print(io, "\\ifnum\\pdfstrcmp{#1}{all}=0%")
    print(io, "\n    ")
    _def_out!(io, name, ind, chomp(JSON.json(obj, 2)))
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
