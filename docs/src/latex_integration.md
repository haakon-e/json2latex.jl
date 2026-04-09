# LaTeX integration guide

## Document setup

Place the generated `.tex` file anywhere LaTeX can find it and load it with
`\input`, before the `\begin{document}` declaration.

```latex
\documentclass{article}
\input{results}   % the .tex suffix is omitted by convention
\begin{document}
  ...
\end{document}
```

## Macro reference

The data can be referenced by,

| Usage                | Expands to                              |
|----------------------|-----------------------------------------|
| `\data`              | Full pretty-printed JSON                |
| `\data[key]`         | Value at `key`                          |
| `\data[key][subkey]` | Nested field access                     |
| `\data[1]`           | First list element (1-based by default) |
| `\data[missing]`     | `??` for any undefined key              |

Values containing LaTeX special characters (`&`, `%`, `$`, `#`, `_`,
`{`, `}`, `~`, `^`, `\`) are escaped automatically and will render as
literal text.

## siunitx

When using `\qty` or `\num` from [siunitx](https://ctan.org/pkg/siunitx),
add the following to your preamble:

```latex
\usepackage{siunitx}
\sisetup{
  parse-numbers = false,
}
```

This is neccessary because siunitx is not able to infer that the provided
data is numeric. Then, numeric data can be used as usual

```latex
\qty{\data[distance]}{\meter}   % typesets the value of "distance" with unit m
\num{\data[count]}              % typesets the value of "count"
```

## Compatibility

The macros use `\pdfstrcmp` for key dispatch. Most modern TeX workflows support
this.
