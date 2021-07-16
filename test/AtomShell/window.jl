using Blink
using Test

@testset "size Tests" begin
    w = Window(Blink.@d(:show => false, :width=>150, :height=>100), async=false);
    @test size(w) == [150,100]

    size(w, 200,200)
    @test size(w) == [200,200]
end
