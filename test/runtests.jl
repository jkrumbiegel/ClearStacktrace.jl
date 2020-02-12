using ClearStacktrace
using Test

module ModuleC
    func_c() = error("Error")
    end


    module ModuleB
    import ..ModuleC
    func_b(::String, ::Rational) = ModuleC.func_c()
    end


    module ModuleA
    import ..ModuleB
    func_a(::Int) = ModuleB.func_b("a", 1//3)
end

@testset "ClearStacktrace.jl" begin
    try
        ModuleA.func_a(1)
    catch e
        st = stacktrace(catch_backtrace())
        Base.show_backtrace(stdout, st)
    end
end

