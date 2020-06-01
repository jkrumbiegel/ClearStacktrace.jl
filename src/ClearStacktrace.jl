module ClearStacktrace


MODULECOLORS = [:light_blue, :light_yellow, :light_green, :light_magenta, :light_cyan, 
:light_red, :blue, :yellow, :green, :magenta, :cyan, :red]

const EXPAND_BASE_PATHS = Ref(true)
const CONTRACT_USER_DIR = Ref(true)
const REPLACE_BACKSLASHES = Ref(true)
const _LAST_CONVERTED_TRACE = Ref{Any}(nothing)

function expandbasepath(str)

    basefileregex = if Sys.iswindows()
        r"^\.\\\w+\.jl$"
    else
        r"^\./\w+\.jl$"
    end

    if !isnothing(match(basefileregex, str))
        sourcestring = Base.find_source_file(str[3:end]) # cut off ./
    else
        str
    end
end

function replaceuserpath(str)
    str1 = replace(str, homedir() => "~")
    # seems to be necessary for some paths with small letter drive c:// etc
    replace(str1, lowercasefirst(homedir()) => "~")
end

function replacebackslashes(str)
    replace(str, raw"\\" => '/')
end

getline(frame) = frame.line
function getfile(frame)
    file = string(frame.file)
    if EXPAND_BASE_PATHS[]
        file = expandbasepath(file)
    end
    if CONTRACT_USER_DIR[]  
        file = replaceuserpath(file)
    end
    if REPLACE_BACKSLASHES[]
        file = replacebackslashes(file)
    end

    file
end
getfunc(frame) = string(frame.func)
getmodule(frame) = try; string(frame.linfo.def.module) catch; "" end

getsigtypes(frame) = try;  frame.linfo.specTypes.parameters[2:end] catch; "" end


function convert_trace(trace)
    files = getfile.(trace)
    lines = getline.(trace)

    methodss = map(trace) do t
        try
            t.linfo.def
        catch
            nothing
        end
    end

    arguments = map(methodss) do m
        if isnothing(m)
            []
        else
            tv, decls, file, line = Base.arg_decl_parts(m)
            decls[2:end]
        end
    end

    funcs = getfunc.(trace)
    moduls = getmodule.(trace)
    sigtypes = getsigtypes.(trace)
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
        moduls = moduls, sigtypes = sigtypes, inlineds = inlineds, arguments = arguments)
end



function printtrace(io::IO, converted_stacktrace)

    files, lines, funcs, moduls, sigtypes, inlineds, arguments = converted_stacktrace

    numbers = [string(i) for i in 1:length(files)]
    numwidth = maximum(length, numbers)
    numbrackets = [lpad("[" * num, numwidth + 1) * "]" for num in numbers]

    exts = [inl ? " [i]" : "" for inl in inlineds]

    uniquemodules = setdiff(unique(moduls), [""])
    modulecolors = Dict(u => c for (u, c) in
        Iterators.zip(uniquemodules, Iterators.cycle(MODULECOLORS)))

    for (i, (num, func, ext, modul, file, line, stypes, args)) in enumerate(
            zip(numbrackets, funcs, exts, moduls, files, lines, sigtypes, arguments))

        modulecolor = get(modulecolors, modul, :default)

        print(io, num)
        print(io, " ")
        
        printstyled(io, func, bold = true)
        
        printstyled(io, "(", color = :light_black)

        i = 1
        for (stype, (varname, vartype)) in zip(stypes, args)
            if i > 1
                printstyled(io, ", ", color = :light_black)
            end
            printstyled(io, string(varname), color = :light_black, bold = true)
            printstyled(io, "::")
            printstyled(io, string(stype), color = :light_black)
            i += 1
        end

        printstyled(io, ")", color = :light_black)

        println(io)
        
        printstyled(io, " " ^ (length(num) - 1) * "@ ", color = :light_black)

        if !isempty(modul)
            printstyled(io, modul, color = modulecolor)
            print(io, " ")
        end

        pathparts = splitpath(file)
        for p in pathparts[1:end-1]
            printstyled(io, p * "/", color = :light_black)
        end

        printstyled(io, pathparts[end], color = :light_black, bold = true)
        printstyled(io, ":", color = :light_black)
        printstyled(io, string(line), color = :light_black, bold = true)

        printstyled(io, ext, color = :light_black)

        println(io)
        println(io)
    end
end


@warn "Overloading Base.show_backtrace(io::IO, t::Vector) with custom version"
function Base.show_backtrace(io::IO, t::Vector)

    ### this part is copied from the original function
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
    ###

    if length(filtered) > Base.BIG_STACKTRACE_SIZE
        Base.show_reduced_backtrace(IOContext(io, :backtrace => true), filtered, true)
        return
    end

    println(io, "\nStacktrace:")

    # process_backtrace returns a Tuple{Frame, Int}
    frames = first.(filtered)

    converted_stacktrace = convert_trace(frames)
    _LAST_CONVERTED_TRACE[] = converted_stacktrace

    printtrace(io, converted_stacktrace)
end

function reprint_last(; full = true)
    if !isnothing(_LAST_CONVERTED_TRACE[])
        printtrace(stdout, _LAST_CONVERTED_TRACE[])
    end
end


end # module
