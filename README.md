# TexData.jl

Make Julia data accessible directly in LaTeX documents — no more pasting and updating values by hand.

Save numbers and text from your simulations, experiments, and analyses:

```julia
using TexData
write_tex(Dict("accuracy" => 0.974, "n" => 2000, "lr" => 0.001, "epochs" => 50), "results")
```

then easily insert the values into your LaTeX document:

```latex
\documentclass{article}
\input{results}
\begin{document}
% In prose:
The model achieved \results[accuracy] accuracy on \results[n] test samples.

% In an equation:
\begin{equation}
    \mathcal{L}_{\results[epochs]} = \results[accuracy]
\end{equation}

% Inline math:
Training used learning rate $\eta = \results[lr]$ for \results[epochs] epochs.
\end{document}
```

View this code sample as a pdf document [here](https://www.overleaf.com/read/rwjkvpdbtqjv#a7cc84).

---

## Installation

### As a library

```julia
using Pkg
Pkg.add(url="https://github.com/haakon-e/TexData.jl")
```

### As a CLI app (Julia ≥ 1.12)

```julia
using Pkg
Pkg.Apps.add(url="https://github.com/haakon-e/TexData.jl")
```
This installs the `texdata` command to `~/.julia/bin/`. Make sure this directory is in your `PATH`.

---

## Usage

```julia
using TexData

results = Dict("accuracy" => 0.974, "n" => 2000, "lr" => 0.001, "epochs" => 50)
name = "results"   # becomes \results in LaTeX

# Write to results.tex in the current directory
write_tex(results, name)

# Or write to a specific path
write_tex(results, name; tex_file = "paper/results.tex")
```

To persist data across runs and keep a human-readable JSON record alongside the TeX file:

```julia
# Creates results.json + results.tex on first call; 
# merges and regenerates on subsequent calls
sync_tex!("results.json", results)
```

If you prefer to maintain the JSON file manually or use it from another tool, generate the
TeX from the command line:

```bash
texdata results.json               # → results.tex, \results
texdata results.json --name res    # use a different macro name
texdata results.json --output paper/results.tex
```

See the [documentation](https://haakon-e.github.io/TexData.jl) for the full API reference
and LaTeX integration guide.

---

## Acknowledgements

This package is a Julia port of the
[json2latex](https://github.com/CameronDevine/json2latex) Python library.

---

## License

MIT — see [LICENSE](LICENSE).
