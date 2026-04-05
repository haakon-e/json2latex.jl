using Documenter, json2latex

makedocs(
    sitename = "json2latex.jl",
    modules  = [json2latex],
    format   = Documenter.HTML(prettyurls = false),
    pages    = ["Home" => "index.md"],
    remotes  = nothing,
    doctest  = false,
    warnonly = true,
)
