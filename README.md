# ClearStacktrace

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://jkrumbiegel.github.io/ClearStacktrace.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jkrumbiegel.github.io/ClearStacktrace.jl/dev)
[![Build Status](https://travis-ci.com/jkrumbiegel/ClearStacktrace.jl.svg?branch=master)](https://travis-ci.com/jkrumbiegel/ClearStacktrace.jl)
[![Codecov](https://codecov.io/gh/jkrumbiegel/ClearStacktrace.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jkrumbiegel/ClearStacktrace.jl)

An experimental package that hooks into `Base.show_backtrace` and replaces normal StackTrace printing behavior with a clearer version that indicates Modules, uses alignment and Crayon.jl colors to reduce visual clutter and expands base paths so they are clickable.

Example:

!(screenshot)[screenshot.png]

Untested on Windows!

You can choose different preset colors by changing the const Ref variables like:
```julia
ClearStacktrace.MODULECRAYONS[] = [crayon"blue", crayon"green"]
```

