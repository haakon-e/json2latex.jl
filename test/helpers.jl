# ---------------------------------------------------------------------------
# resolve_tex — lightweight TeX macro resolver for integration tests
#
# Simulates \cmd[k1][k2]... expansion on a generated TeX string without
# needing a real TeX engine.  Tests semantic correctness (does the right
# value end up at the right key?) independently of exact layout.
# ---------------------------------------------------------------------------

# Find the closing } of a \def{...} block via brace-depth tracking.
# Characters after \ are skipped so that \{ and \} don't affect depth.
function _find_close_def(s::AbstractString, start::Int)
    depth = 1
    i = start
    while i <= lastindex(s)
        c = s[i]
        if c == '\\'
            i = nextind(s, i)
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

# Unescape the content of a \def block back to the original string.
function _extract_def_content(raw::AbstractString)
    lines = split(raw, "\n")
    result = String[]
    for line in lines
        stripped = startswith(line, "    ") ? line[5:end] : line
        stripped = replace(stripped, r" ?%$" => "")
        push!(result, stripped)
    end
    s = join(result, "\n")
    s = replace(s, raw"\&"  => "&")
    s = replace(s, raw"\%"  => "%")
    s = replace(s, raw"\$"  => "\$")
    s = replace(s, raw"\#"  => "#")
    s = replace(s, raw"\_"  => "_")
    s = replace(s, raw"\{"  => "{")
    s = replace(s, raw"\}"  => "}")
    s = replace(s, raw"\textasciitilde{}" => "~")
    s = replace(s, raw"\^{}" => "^")
    s = replace(s, raw"\textbackslash{}" => "\\")
    s = replace(s, "\\newline%\n" => "\n")
    s = replace(s, "{-}"  => "-")
    s = replace(s, "~"    => "\u00A0")
    s = replace(s, "{[}"  => "[")
    s = replace(s, "{]}"  => "]")
    s
end

# Resolve \CMD[keys...] in a generated TeX string.
# Returns the scalar string value, or "??" for a missing key.
# Call with no keys to get the "all" (full JSON) value.
function resolve_tex(tex::AbstractString, cmd::AbstractString, keys::AbstractString...)
    current_cmd = String(cmd)
    for key in keys
        header = "\\newcommand\\$(current_cmd)[1][all]{%"
        hpos = findfirst(header, tex)
        isnothing(hpos) && return "??"
        search_start = last(hpos) + 1

        next_cmd_pos = findnext("\\newcommand\\", tex, search_start)
        block_end = isnothing(next_cmd_pos) ? lastindex(tex) : first(next_cmd_pos) - 1
        block = SubString(tex, search_start, block_end)

        key_str = "\\ifnum\\pdfstrcmp{#1}{$(key)}=0%\n      "
        kpos = findfirst(key_str, block)
        isnothing(kpos) && return "??"

        after_key = last(kpos) + 1
        rest = SubString(block, after_key)

        if startswith(rest, "\\let")
            nl = findfirst('\n', rest)
            line = isnothing(nl) ? String(rest) : String(rest[1:nl-1])
            line = rstrip(line, '%')
            bp = findlast('\\', line)
            isnothing(bp) && return "??"
            current_cmd = line[bp+1:end]
        elseif startswith(rest, "\\def")
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

    # No more keys — return the "all" value for current_cmd.
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
