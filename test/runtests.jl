using ClearStacktrace
using Test

@testset "ClearStacktrace.jl" begin
    # Write your own tests here.
end

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

ModuleA.func_a(1)