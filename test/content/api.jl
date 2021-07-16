using Blink
using Test

@testset "content! Tests" begin
    w = Window(Blink.@d(:show => false), async=false);
    body!(w, "", async=false);
    @test (@js w document.querySelector("body").innerHTML) == ""

    # Test reloading body and a selector element.
    html = """<div id="a">hi world</div><div id="b">bye</div>"""
    body!(w, html, async=false);
    @test (@js w document.getElementById("a").innerHTML) == "hi world"
    @test (@js w document.getElementById("b").innerHTML) == "bye"
    content!(w, "div", "hello world", async=false);
    @test (@js w document.getElementById("a").innerHTML) == "hello world"
    # TODO(nhdaly): Is this right? Should content!(w,"div",...) change _all_ divs?
    @test (@js w document.getElementById("b").innerHTML) == "bye"
end


@testset "Fade" begin
    fade_test_html = """
        <script>var testJS = "test";</script>
        <div id="d">hi world</div>
        """
    # Test `fade` parameter and scripts:
    # Must create a new window to ensure javascript is reset.
    @testset "Fade True" begin
        w = Window(Blink.@d(:show => false), async=false);
        body!(w, fade_test_html; fade=true, async=false);
        @test (@js w testJS) == "test"
    end

    @testset "Fade False" begin
        w = Window(Blink.@d(:show => false), async=false);
        body!(w, fade_test_html; fade=false, async=false);
        @test (@js w testJS) == "test"
    end
end

@testset "Sync/Async content reload tests" begin
    w = Window(Blink.@d(:show => false), async=false);
    sleep_content(seconds) = """
        <script>
            function spinsleep(ms) {
                var start = new Date().getTime(), expire = start + ms;
                while (new Date().getTime() < expire) { }
                return;
            }
            spinsleep($(seconds * 1000));
        </script>
      """

    @timed sleep(0.1);   # Throw-away statement to warm-up @sync and @async

    x, t = @timed body!(w, sleep_content(3); fade=true, async=false)
    #@test x == true  # TODO: What should it return?
    @test t >= 3.0 # seconds

    x, t = @timed body!(w, sleep_content(3); fade=false, async=false)
    @test t >= 3.0 # seconds

    x, t = @timed body!(w, sleep_content(3); fade=true, async=true);
    @test t < 3.0 # seconds
    sleep(3)  # (Wait until the end of the previous body! call.)

    x, t = @timed body!(w, sleep_content(3); fade=false, async=true);
    @test t < 3.0 # seconds
    sleep(3)  # (Wait until the end of the previous body! call.)


    @sync begin  # Throw-away block to warm-up @sync and @async
        @async sleep(0.1)
        @async sleep(0.1)
    end
    # Test using Julia's async mechanisms with synchronous `content!`.
    _, t = @timed @sync begin
      @async body!(w, sleep_content(4); async=false);
      sleep(4)
    end

    @test t >= 4.0
    @test t < 8
end
