using Documenter, TexData

makedocs(
    sitename = "TexData.jl",
    modules  = [TexData],
    format   = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
    ),
    pages    = [
        "Home"              => "index.md",
        "LaTeX integration" => "latex_integration.md",
    ],
    doctest   = false,
    checkdocs = :exports,
)

deploydocs(
    repo         = "github.com/haakon-e/TexData.jl",
    devbranch    = "main",
    push_preview = true,
)
