module ClearStacktrace

using Crayons

const MODULECRAYONS = Ref(
        [
            crayon"blue",
            crayon"yellow",
            crayon"red",
            crayon"green",
            crayon"cyan",
            crayon"magenta",
        ]
)
const TYPECOLORS = Ref(Any[:dark_gray, :dark_gray, :dark_gray])
const CRAYON_HEAD = Ref(Crayon(bold = true))
const CRAYON_HEADSEP = Ref(Crayon(bold = true))
const CRAYON_FUNCTION = Ref(Crayon())
const CRAYON_FUNC_EXT = Ref(Crayon(foreground = :dark_gray))
const CRAYON_LOCATION = Ref(Crayon(foreground = :dark_gray))
const CRAYON_NUMBER = Ref(Crayon(foreground = :blue))
const CRAYON_HIDDEN_CHARS = Ref(Crayon(foreground = 131))
const NUMPAD = Ref(1)
const FUNCPAD = Ref(2)
const MODULEPAD = Ref(2)
const EXPAND_BASE_PATHS = Ref(true)
const CONTRACT_USER_DIR = Ref(true)
const LOCATION_PREFIX = Ref("at: ")
const DEFAULT_MODULE_CRAYON = Ref(Crayon(foreground = :default))
const INLINED_SIGN = Ref("[i]")
const REPLACE_BACKSLASHES = Ref(true)
const _LAST_CONVERTED_TRACE = Ref{Any}(nothing)
const MAX_SIGNATURE_CHARS = Ref(200)


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



function printtrace(io::IO, converted_stacktrace; maxsigchars = MAX_SIGNATURE_CHARS[])

    files, lines, funcs, moduls, signatures, inlineds = converted_stacktrace

    numbers = ["[" * string(i) * "]" for i in 1:length(files)]
    numwidth = maximum(length, numbers)

    exts = [inl ? " " * INLINED_SIGN[] : "" for inl in inlineds]
    funcs_w_ext = funcs .* exts
    funcwidth = maximum(length, funcs_w_ext)

    modulwidth = max(maximum(length, moduls), length("Module"))

    umoduls = setdiff(unique(moduls), [""])
    modcrayons = Dict(u => c for (u, c) in
        Iterators.zip(umoduls, Iterators.cycle(MODULECRAYONS[])))

    print(io, rpad("", numwidth + NUMPAD[]))
    print(io, CRAYON_HEAD[](rpad("Function", funcwidth + FUNCPAD[])))
    print(io, CRAYON_HEAD[](rpad("Module", modulwidth + MODULEPAD[])))
    print(io, CRAYON_HEAD[]("Signature"))
    println(io)

    print(io, rpad("", numwidth + NUMPAD[]))
    print(io, CRAYON_HEADSEP[](rpad("────────", funcwidth + FUNCPAD[])))
    print(io, CRAYON_HEADSEP[](rpad("──────", modulwidth + MODULEPAD[])))
    print(io, CRAYON_HEADSEP[]("─────────"))
    println(io)

    for (i, (num, func, ext, modul, file, line, signature)) in enumerate(
            zip(numbers, funcs, exts, moduls, files, lines, signatures))
        print(io, CRAYON_NUMBER[](rpad(num, numwidth + NUMPAD[])))

        print(io, CRAYON_FUNCTION[](func))

        print(io, CRAYON_FUNC_EXT[](ext * (" " ^ (FUNCPAD[] + funcwidth - length(funcs_w_ext[i])))))

        mcrayon = get(modcrayons, modul, DEFAULT_MODULE_CRAYON[])
        print(io, mcrayon(rpad(modul, modulwidth + MODULEPAD[])))

        print_signature(io, signature)

        println(io)

        println(io, CRAYON_LOCATION[](LOCATION_PREFIX[] * string(file) * ":" * string(line)))
    end
end

function print_signature(io::IO, signature)
    # print each :: from the signature in white and the rest in dark gray
    for part in split(signature, "::")
        if isempty(part)
            continue
        end
        print(io, "::")
        print(io, Crayon(foreground = :dark_gray)(part))
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
        printtrace(stdout, _LAST_CONVERTED_TRACE[];
            maxsigchars = full ? typemax(Int) : MAX_SIGNATURE_CHARS[])
    end
end


end # module
