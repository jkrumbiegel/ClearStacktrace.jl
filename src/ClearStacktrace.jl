module ClearStacktrace

using Crayons

st = try 
    scene, layout = layoutscene()
    ax = layout[1, 1] = LAxis(scene)
    scatter!(ax, rand(100, 4))
catch e
    stacktrace(catch_backtrace())
end


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
getfile(frame) = string(frame.file) |> expandbasepath
getfunc(frame) = string(frame.func)
getmodule(frame) = try; string(frame.linfo.def.module) catch; "" end

getsig(frame) = try;  join("::" .* repr.(frame.linfo.specTypes.parameters[2:end]), ", ::") catch; "" end
getlocation(frame) = string(getfile(frame)) * ":" * string(getline(frame)) |> replaceuserpath

function convert_frame(frame)
    (
        location = getlocation(frame),
        func = getfunc(frame),
        modul = getmodule(frame),
        inlined = frame.inlined,
        signature = getsig(frame),
    )
end

convert_trace(trace) = convert_frame.(trace)


colors = [:red, :blue, :green, :yellow, :orange, :cyan, :magenta];

function printtrace(stacktrace)

    arrframes = convert_trace(stacktrace)

    numbers = ["[" * string(i) * "]" for i in 1:length(arrframes)]
    numwidth = maximum(length, numbers)

    funcs = [x.func for x in arrframes]
    exts = [x.inlined ? " [i]" : "" for x in arrframes]
    funcs_w_ext = funcs .* exts
    funcwidth = maximum(length, funcs_w_ext)

    moduls = [x.modul for x in arrframes]
    modulwidth = maximum(length, moduls)

    umoduls = setdiff(unique(moduls), [""])
    ucolors = Dict(u => c for (u, c) in Iterators.zip(umoduls, colors))

    locations = [x.location for x in arrframes]

    signatures = [x.signature for x in arrframes]

    headcrayon = Crayon(bold = true)
    print(rpad("", numwidth + 1))
    # print(headcrayon(rpad("No.", numwidth + 1)))
    print(headcrayon(rpad("Function", funcwidth + 2)))
    print(headcrayon(rpad("Module", modulwidth + 2)))
    print(headcrayon("Signature"))
    println()
    # print(headcrayon(rpad("┄┄┄", numwidth + 1)))
    print(rpad("", numwidth + 1))
    print(headcrayon(rpad("┄┄┄┄┄┄┄┄", funcwidth + 2)))
    print(headcrayon(rpad("┄┄┄┄┄┄", modulwidth + 2)))
    print(headcrayon("┄┄┄┄┄┄┄┄┄"))
    println()

    for (i, (num, func, ext, modul, location, signature)) in enumerate(zip(numbers, funcs, exts, moduls, locations, signatures))
        ncrayon = Crayon(foreground = :blue)
        print(ncrayon(rpad(num, numwidth + 1)))

        fcrayon = Crayon(bold = false)
        print(fcrayon(func))

        extcrayon = Crayon(foreground = :dark_gray)
        print(extcrayon(ext * (" " ^ (2 + funcwidth - length(funcs_w_ext[i])))))

        mcolor = get(ucolors, modul, :white)
        mcrayon = Crayon(foreground = mcolor)
        print(mcrayon(rpad(modul, modulwidth + 2)))

        # sigcrayon = Crayon(foreground = :dark_gray)
        # print(sigcrayon(signature))
        highlight_signature_2(signature, [0x607070, 0x706070, 0x707060])
        
        println()
        loccrayon = Crayon(foreground = :dark_gray)
        # loccrayon = Crayon(foreground = 0x666666)
        println(loccrayon(location))
    end
end

printtrace(st);


function highlight_signature_2(sig, colors = [:red, :yellow, :blue])
    # split before and after curly braces and commas
    regex = r"(?<=[\{\}\,])|(?=[\{\}\,])"

    parts = split(sig, regex)


    colorstack = colors[1:2]

    lastbrace = :open

    for p in parts
        color = nothing

        if p == "{"
            color = colorstack[end]
            push!(colorstack, colorstack[end-1])
        elseif p == "}"
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
        print(cray(p))
    end

end


end # module
