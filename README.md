# json2latex.jl

`json2latex` converts JSON data or any dictionary-like Julia structure into
LaTeX macro definitions that make the data accessible directly inside a `.tex`
document.

---

## Installation

### As a library

```julia
using Pkg
Pkg.add(url="https://github.com/haakon-e/json2latex.jl")
```

### As a CLI app (Julia ≥ 1.12)

```julia
using Pkg
Pkg.Apps.add(url="https://github.com/haakon-e/json2latex.jl")
```
This installs the `json2latex` command to `~/.julia/bin/`. Make sure this directory is in your `PATH`.

---

## Usage

### From a JSON file

Given `experiment.json`:

```json
{
    "title":    "Ablation study",
    "baseline": 0.83,
    "trial2":   0.91,
    "trial10":  0.94,
    "tags":     ["vision", "classification"],
    "config":   { "lr": 0.001, "epochs": 50 }
}
```

From the command line:

```bash
json2latex experiment.json                               # → experiment.tex, \experiment
json2latex experiment.json --name exp --output build/exp.tex
json2latex experiment.json --base 0                      # 0-based list indexing (default is 1-based)
```

From Julia:

```julia
using json2latex
generate_tex("experiment.json")
```

Then in your LaTeX document:

```latex
\input{experiment}

\experiment[title]        %% → Ablation study
\experiment[baseline]     %% → 0.83
\experiment[trial2]       %% → 0.91
\experiment[tags][1]      %% → vision  (lists are 1-based by default)
\experiment[config][lr]   %% → 0.001
\experiment               %% → full pretty-printed JSON
```

### From a Julia dict

```julia
using json2latex

cfg = OrderedDict(
    "author"  => "Ada Lovelace",
    "version" => "1.0",
    "runs"    => [10, 20, 30],
)
generate_tex!("cfg.json", cfg)
```

```latex
\input{cfg}
\cfg[author]    %% → Ada Lovelace
\cfg[runs][1]   %% → 10
\cfg[runs][2]   %% → 20
\cfg            %% → {"author": "Ada Lovelace", "version": "1.0", "runs": [10, 20, 30]}
```

`OrderedDict` is re-exported by `json2latex` — no extra `using` needed.
A plain `Dict` also works but does not guarantee key order.
`NamedTuple`s are accepted as dictionary-like inputs.

### Incremental update workflow

For workflows where data accumulates across multiple runs:

```julia
# First run — creates metrics.json and metrics.tex
generate_tex!("metrics.json", Dict("loss" => 0.12, "epoch" => 1))

# Later run — merges new keys, regenerates both files
generate_tex!("metrics.json", Dict("loss" => 0.04, "epoch" => 10))
```

Pass `overwrite=true` to discard any existing data and start fresh.

---

## Macro reference

After `\input{data}`, the command `\data` accepts an optional argument:

| LaTeX call              | Expands to                                   |
|-------------------------|----------------------------------------------|
| `\data` or `\data[all]` | Full pretty-printed JSON                     |
| `\data[key]`            | Value of `key`                               |
| `\data[key][subkey]`    | Nested field access                          |
| `\data[1]`              | First element of a list (1-based by default) |
| `\data[missing]`        | `??` for any undefined key                   |

The macros use `\pdfstrcmp` for dispatch and are compatible with pdfLaTeX and
LuaLaTeX. LaTeX special characters in values are escaped automatically.

---

## Acknowledgements

This package is a Julia port of the
[json2latex](https://github.com/CameronDevine/json2latex) Python library.

---

## License

MIT — see [LICENSE](LICENSE).
