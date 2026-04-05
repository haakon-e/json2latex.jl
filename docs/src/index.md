# json2latex.jl

`json2latex` converts JSON data or any dictionary-like Julia structure into
LaTeX macro definitions that make the data accessible directly inside a
`.tex` document.

---

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/yourname/json2latex.jl")
```

To install the CLI app (Julia ≥ 1.12):

```julia
Pkg.app("json2latex")
```

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

Generate the `.tex` file — from the command line:

```bash
json2latex experiment.json                               # → experiment.tex, \experiment
json2latex experiment.json --name exp --output build/exp.tex
json2latex experiment.json --base 0                      # 0-based list indexing
```

Or from Julia:

```julia
using json2latex

generate_tex("experiment.json")
generate_tex("experiment.json"; name = "exp", tex_file = "build/exp.tex")
```

Then in your LaTeX document:

```latex
\input{experiment}

\experiment[title]          %% → Ablation study
\experiment[baseline]       %% → 0.83
\experiment[trial2]         %% → 0.91   (digit keys work without any escaping)
\experiment[tags][1]        %% → vision  (lists are 1-based by default)
\experiment[config][lr]     %% → 0.001
\experiment                 %% → full pretty-printed JSON
```

### From a Julia dict

```julia
using json2latex

tex = dumps("cfg", OrderedDict(
    "author"  => "Ada Lovelace",
    "version" => "1.0",
    "runs"    => [10, 20, 30],
))
write("cfg.tex", tex)
```

```latex
\input{cfg}
\cfg[author]    %% → Ada Lovelace
\cfg[runs][1]   %% → 10
\cfg[runs][2]   %% → 20
\cfg            %% → {"author": "Ada Lovelace", "version": "1.0", "runs": [10, 20, 30]}
```

`OrderedDict` is re-exported by `json2latex` — no extra import needed.
A plain `Dict` works but does not guarantee key order.
`NamedTuple`s are also accepted as dictionary-like inputs.

### Incremental update workflow

For workflows where data accumulates across multiple runs:

```julia
# First run — creates metrics.json and metrics.tex
generate_tex!("metrics.json", Dict("loss" => 0.12, "epoch" => 1))

# Later run — merges new keys, regenerates both files
generate_tex!("metrics.json", Dict("loss" => 0.04, "epoch" => 10))
```

---

## Notes

- `\name` or `\name[all]` — full pretty-printed JSON
- `\name[key]` — value at `key`; `\name[key][subkey]` — nested access
- `\name[1]` — first element of a list (1-based by default; `base=0` for 0-based)
- Missing keys always expand to `??`
- `nothing` / JSON `null` → `"null"`, booleans → `"true"` / `"false"`
- LaTeX special characters (`&`, `%`, `$`, `#`, `_`, `{`, `}`, `~`, `^`, `\`) in
  values are escaped automatically

---

## API

```@docs
dumps
generate_tex
generate_tex!
```

---

## Attribution

This is a Julia port of the [json2latex](https://github.com/CameronDevine/json2latex) Python library.

MIT License — see [LICENSE](../LICENSE).
