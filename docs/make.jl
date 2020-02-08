using Documenter, ClearStacktrace

makedocs(;
    modules=[ClearStacktrace],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/jkrumbiegel/ClearStacktrace.jl/blob/{commit}{path}#L{line}",
    sitename="ClearStacktrace.jl",
    authors="Julius Krumbiegel",
    assets=String[],
)

deploydocs(;
    repo="github.com/jkrumbiegel/ClearStacktrace.jl",
)
