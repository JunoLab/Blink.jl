using Blink
using Test
using Sockets


cleanup = !AtomShell.isinstalled()

cleanup && AtomShell.install()

# open window and wait for it to initialize
@testset "basic functionality" begin
    w = Window(Blink.@d(:show => false), async=false);
    # make sure the window is really active
    @test @js(w, Math.log(10)) ≈ log(10)

    @test string(Blink.jsstring(:(Dict("a" => 1, :b => 10)))...) == "{\"a\":1,\"b\":10}"

    # check that <!DOCTYPE html> was declared
    @test  startswith(Blink.maintp.tokens[1].value, "<!DOCTYPE html>\n")
end

include("content/api.jl");
include("AtomShell/window.jl");
include("./webio.jl")

if Sys.iswindows()
    # Uninstalling AtomShell on Windows is currently broken:
    # https://github.com/JunoLab/Blink.jl/pull/143#issuecomment-414144008
    cleanup = false
end
cleanup && AtomShell.uninstall()
