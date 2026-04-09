```@raw html
<div align="center">
  <img src="assets/logo.svg" alt="TexData.jl Logo" width="400">
</div>
```

# TexData.jl

Make Julia data accessible directly in LaTeX documents — no more pasting and updating values by hand.

---

## Quick start

```julia
# Install as a package
using Pkg; Pkg.add(url="https://github.com/haakon-e/TexData.jl")
# Install as a CLI tool (Julia ≥ 1.12) → provides `texdata` terminal command
using Pkg; Pkg.Apps.add(url="https://github.com/haakon-e/TexData.jl")
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

write_tex("results", results)
```
This will create a `results.tex` file in the current directory.
Place this file in a directory where LaTeX can find it, 
for example the same directory as your main `.tex` file.

Then easily insert the values into your LaTeX document:

```tex
\input{results}

% In prose:
The model achieved \results[accuracy] accuracy on \results[n] test samples.

% In an equation:
\begin{equation}
    \mathcal{L}_{\results[epochs]} = \results[accuracy]
\end{equation}

% Inline math:
Training used learning rate $\eta = \results[lr]$ for \results[epochs] epochs.
```

View this code sample as a pdf document [here](https://www.overleaf.com/read/rwjkvpdbtqjv#a7cc84).

---

## Usage

### Julia data → TeX

```julia
write_tex("results", results)                              # → results.tex
write_tex("results", results; tex_file = "build/res.tex") # custom output path
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

!!! note "NOTE: Recursive merge is currently not supported"
    That is, if the value of
    a top-level key differ between the new data and JSON file, the value
    of the new data overwrites all data in the JSON file at that key.

### Command line interface (CLI)

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

## Use in LaTeX documents

See the [LaTeX integration guide](@ref) for how to use the
generated `.tex` file in a document, including siunitx compatibility and a full
macro reference table.

---

## Attribution

This is a Julia port of the [json2latex](https://github.com/CameronDevine/json2latex) Python library.

MIT License — see [LICENSE](https://github.com/haakon-e/TexData.jl/blob/main/LICENSE).
