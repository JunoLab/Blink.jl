using Blink
using Test


# IMPORTANT: Window(...) cannot appear inside of a @testset for as-of-yet
# unknown reasons.
w = Window(Blink.@d(:show => false, :width=>150, :height=>100), async=false);
@testset "size Tests" begin
    @test size(w) == (150, 100)

    size(w, 200, 200)
    @test size(w) == (200, 200)
end

# @testset "async" begin
#     # Test that async Window() creation is faster than synchronous creation.
#     # (Repeat the test a few times, just to be sure it's consistent.)
#     for _ in 1:5
#         (@timed Window(Blink.@d(:show => false), async=true))[2] <
#          (@timed Window(Blink.@d(:show => false), async=false))[2]
#     end
# # end
