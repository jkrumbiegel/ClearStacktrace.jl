module ClearStacktrace

using Crayons

const COLORS = Ref(Any[:blue, :yellow, :red, :green, :orange, :cyan, :magenta])
const TYPECOLORS = Ref(Any[0x706060, 0x607060, 0x606080])
const CRAYON_HEAD = Ref(Crayon(bold = true))
const CRAYON_HEADSEP = Ref(Crayon(bold = true))
const CRAYON_FUNCTION = Ref(Crayon())
const CRAYON_FUNC_EXT = Ref(Crayon(foreground = :dark_gray))
const CRAYON_LOCATION = Ref(Crayon(foreground = :dark_gray))
const CRAYON_NUMBER = Ref(Crayon(foreground = :blue))
const NUMPAD = Ref(1)
const FUNCPAD = Ref(2)
const MODULEPAD = Ref(2)


function expandbasepath(str)
    if !isnothing(match(r"^\./\w+\.jl$", str))
        sourcestring = Base.find_source_file(str[3:end]) # cut off ./
        replace(sourcestring, raw"\\" => '/')
    else
        str
    end
end

function replaceuserpath(str)
    str1 = replace(str, homedir() => "~")
    # seems to be necessary for some paths with small letter drive c:// etc
    replace(str1, lowercasefirst(homedir()) => "~")
end

getline(frame) = frame.line
getfile(frame) = string(frame.file) |> expandbasepath |> replaceuserpath
getfunc(frame) = string(frame.func)
getmodule(frame) = try; string(frame.linfo.def.module) catch; "" end

getsig(frame) = try;  join("::" .* repr.(frame.linfo.specTypes.parameters[2:end]), ", ") catch; "" end


function convert_trace(trace)
    files = getfile.(trace)
    lines = getline.(trace)
    funcs = getfunc.(trace)
    moduls = getmodule.(trace)
    signatures = getsig.(trace)
    inlineds = getfield.(trace, :inlined)

    # replace empty modules if there is another frame from the same file
    for (i_this, mo) in enumerate(moduls)
        if mo == ""
            for i_other in 1:length(trace)
                if files[i_this] == files[i_other] && moduls[i_other] != ""
                    moduls[i_this] = moduls[i_other]
                end
            end
        end
    end

    (files = files, lines = lines, funcs = funcs,
        moduls = moduls, signatures = signatures, inlineds = inlineds)
end



function printtrace(io::IO, stacktrace)

    files, lines, funcs, moduls, signatures, inlineds = convert_trace(stacktrace)

    numbers = ["[" * string(i) * "]" for i in 1:length(stacktrace)]
    numwidth = maximum(length, numbers)

    exts = [inl ? " [i]" : "" for inl in inlineds]
    funcs_w_ext = funcs .* exts
    funcwidth = maximum(length, funcs_w_ext)

    modulwidth = max(maximum(length, moduls), length("Module"))

    umoduls = setdiff(unique(moduls), [""])
    ucolors = Dict(u => c for (u, c) in Iterators.zip(umoduls, COLORS[]))

    # locations = [x.location for x in arrframes]

    print(io, rpad("", numwidth + NUMPAD[]))
    # print(io, CRAYON_HEAD[](rpad("No.", numwidth + 1)))
    print(io, CRAYON_HEAD[](rpad("Function", funcwidth + FUNCPAD[])))
    print(io, CRAYON_HEAD[](rpad("Module", modulwidth + MODULEPAD[])))
    print(io, CRAYON_HEAD[]("Signature"))
    println(io)
    # print(io, CRAYON_HEAD[](rpad("┄┄┄", numwidth + 1)))
    print(io, rpad("", numwidth + NUMPAD[]))
    print(io, CRAYON_HEADSEP[](rpad("┄┄┄┄┄┄┄┄", funcwidth + FUNCPAD[])))
    print(io, CRAYON_HEADSEP[](rpad("┄┄┄┄┄┄", modulwidth + MODULEPAD[])))
    print(io, CRAYON_HEADSEP[]("┄┄┄┄┄┄┄┄┄"))
    println(io)

    for (i, (num, func, ext, modul, file, line, signature)) in enumerate(
            zip(numbers, funcs, exts, moduls, files, lines, signatures))
        print(io, CRAYON_NUMBER[](rpad(num, numwidth + NUMPAD[])))

        print(io, CRAYON_FUNCTION[](func))

        print(io, CRAYON_FUNC_EXT[](ext * (" " ^ (FUNCPAD[] + funcwidth - length(funcs_w_ext[i])))))

        mcolor = get(ucolors, modul, :white)
        mcrayon = Crayon(foreground = mcolor)
        print(io, mcrayon(rpad(modul, modulwidth + MODULEPAD[])))

        # sigcrayon = Crayon(foreground = :dark_gray)
        # print(io, sigcrayon(signature))
        print_signature(io, signature, TYPECOLORS[])
        
        println(io)
        # CRAYON_LOCATION = Crayon(foreground = 0x666666)
        println(io, CRAYON_LOCATION[](string(file) * ":" * string(line)))
    end
end

function print_signature(io::IO, sig, colors)
    # split before and after curly braces and commas

    if length(colors) != 3
        error("""
        Three colors are needed to color a type signature without collisions.
        You supplied $(length(colors)): $colors
        """)
    end

    if isempty(sig)
        return
    end

    regex = r"(?<=[\{\}\,])|(?=[\{\}\,])"

    parts = split(sig, regex)

    # pretend that we used two colors already to avoid the edge case
    colorstack = colors[1:2]

    print(io, Crayon(foreground = :dark_gray)("("))
    for p in parts
        color = nothing

        if p == "{"
            # opening brace has same color as previous word
            color = colorstack[end]
            # now add the color of the word before that to the end of the stack
            # so the next chosen color will be neither of these two
            push!(colorstack, colorstack[end-1])
        elseif p == "}"
            # closing brace gets the color from the previous stack level
            # remove that one
            pop!(colorstack)
            color = colorstack[end]
        elseif p == ","
            color = :dark_gray
        else
            # change color for every element, choose not the last two ones
            color = setdiff(colors, colorstack[end-1:end])[1]
            # then change the last color to the current ones
            colorstack[end] = color
        end
        
        cray = Crayon(foreground = color)
        print(io, cray(p))
    end
    print(io, Crayon(foreground = :dark_gray)(")"))
end

@warn "Overloading Base.show_backtrace(io::IO, t::Vector) with custom version"
function Base.show_backtrace(io::IO, t::Vector)

    resize!(Base.LAST_SHOWN_LINE_INFOS, 0)
    filtered = Base.process_backtrace(t)
    isempty(filtered) && return

    if length(filtered) == 1 && StackTraces.is_top_level_frame(filtered[1][1])
        f = filtered[1][1]
        if f.line == 0 && f.file == Symbol("")
            # don't show a single top-level frame with no location info
            return
        end
    end

    println(io, "\nStacktrace:")

    frames = first.(filtered)

    printtrace(io, frames)

end


end # module
