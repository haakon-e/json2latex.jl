# TexData.jl

A Julia package for making data accessible directly in LaTeX documents.

---

## Quick start

```julia
using Pkg; Pkg.add(url="https://github.com/haakon-e/TexData.jl")
using Pkg; Pkg.Apps.add(url="https://github.com/haakon-e/TexData.jl")  # as a CLI tool (Julia ≥ 1.12)
```

Julia Apps are installed to `~/.julia/bin/`. Ensure this directory is in your `PATH` to use the CLI tool.

Save numbers and text from your simulations, experiments, and analyses:

```julia
using TexData

results = Dict(
    "model"    => "ResNet-50",
    "accuracy" => 0.974,
    "task1"    => "vision",
    "config"   => Dict("lr" => 0.001, "epochs" => 50),
)

write_tex(results, "results")
```

Then easily insert the values into your LaTeX document:

```latex
\input{results}

% In prose:
We evaluate \results[model] on the \results[task1] task,
achieving \results[accuracy] accuracy.

% In an equation:
\begin{equation}
    \mathcal{L} = f\!\left(\eta = \results[config][lr]\right)
\end{equation}

% Inline math:
Training ran for $n = \results[config][epochs]$ epochs.
```

---

## Usage

### Julia data → TeX

```julia
write_tex(results, "results")                              # → results.tex
write_tex(results, "results"; tex_file = "build/res.tex") # custom output path
```

The `results` data can be a plain `Dict`. To ensure the order of keys are
preserved, it is recommended to use an `OrderedDict`, which is re-exported -
no extra import needed.

### JSON backing store

The `sync_tex!` method uses JSON as a human-readable storage, from which the
TeX file is generated,
```julia
# Creates results.json + results.tex
sync_tex!("results.json", Dict("model" => "ResNet-50", "accuracy" => 0.974))

# Subsequent calls, updates results.json and regenerates results.tex
sync_tex!("results.json", Dict("accuracy" => 0.993))
```
Pass `overwrite = true` to discard existing JSON data and start fresh.

!!! NOTE: Recursive merge is currently not supported. That is, if the value of
          a top-level key differ between the new data and JSON file, the value
          of the new data overwrites all data in the JSON file at that key.

### CLI

If you edit the JSON file manually or with another tool, generate the TeX file
directly from the command line (requires App installation)
```bash
texdata results.json
texdata results.json --name res --output build/res.tex
```

Learn about the CLI options by
```bash
texdata --help
```

---

## Options

- **`name`** — LaTeX macro name. Inferred from the filename stem for JSON input;
  required when passing data directly. Must contain only ASCII letters.
- **`tex_file`** — output path. Inferred from the input path when omitted.
- **`base`** — starting index for list elements. Default `1` (1-based).
  Pass `base = 0` for 0-based indexing.
- **Key ordering** — use `OrderedDict` to guarantee key order in the JSON file,
  making it easier to organize and inspect the JSON data at a glance.

---

## API reference

```@docs
TexData
write_tex
sync_tex!
dumps
```

---

## LaTeX integration

See the [LaTeX integration guide](latex_integration.html) for how to use the
generated `.tex` file in a document, including siunitx compatibility and a full
macro reference table.

---

## Attribution

This is a Julia port of the [json2latex](https://github.com/CameronDevine/json2latex) Python library.

MIT License — see [LICENSE](https://github.com/haakon-e/TexData.jl/blob/main/LICENSE).
