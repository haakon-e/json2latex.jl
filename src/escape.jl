# Characters that require special treatment in LaTeX body text.
const LATEX_ESCAPES = Dict{Char,String}(
    '&'      => raw"\&",
    '%'      => raw"\%",
    '$'      => raw"\$",
    '#'      => raw"\#",
    '_'      => raw"\_",
    '{'      => raw"\{",
    '}'      => raw"\}",
    '~'      => raw"\textasciitilde{}",
    '^'      => raw"\^{}",
    '\\'     => raw"\textbackslash{}",
    '\n'     => "\\newline%\n",
    '-'      => "{-}",
    '\u00A0' => "~",
    '['      => "{[}",
    ']'      => "{]}",
)

# Escape special LaTeX characters in `s`.
# IOBuffer avoids the O(n²) cost of repeated string concatenation.
# write(io, c::Char) emits the character directly with no heap allocation,
# unlike string(c) which would create a one-character String per call.
function escape_latex(s::AbstractString)
    io = IOBuffer()
    for c in s
        write(io, get(LATEX_ESCAPES, c, c))
    end
    String(take!(io))
end
