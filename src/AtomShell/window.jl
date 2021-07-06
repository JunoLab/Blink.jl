using ..Blink
import Blink: js, id
import JSExpr: JSString, jsstring

export Window, flashframe, shell, progress, title,
  centre, floating, loadurl, opentools, closetools, tools,
  loadhtml, loadfile, css, front

# Keep sorted
export
    center!,
    loadfile!,
    loadurl!,
    opentools!,
    position!,
    progress!,
    title!

mutable struct Window
  id::Int
  shell::Shell
  content
  inittask::Union{Nothing, Task}
end

"""
    Window()
    Window(electron_options::Dict; async=true)

Create and open a new Window through Electron.

If `async=false`, this function blocks until the Window is fully initialized
and ready for you to communicate with it via javascript or the Blink API.

The `electron_options` dict is used to initialize the Electron window. See here
for the full set of Electron options:
https://electronjs.org/docs/api/browser-window#new-browserwindowoptions
"""
function Window end

shell(window::Window) = window.shell
id(window::Window) = window.id

const window_defaults = @d(:url => "about:blank",
                           :title => "Julia",
                           "node-integration" => false,
                           "use-content-size" => true,
                           :icon => resolve_blink_asset("deps", "julia.png"))

raw_window(a::Electron, opts) = @js a createWindow($(merge(window_defaults, opts)))

function Window(a::Shell, opts::AbstractDict = Dict(); async=false)
  # TODO: Custom urls don't support async b/c don't load Blink.js. (Same as https://github.com/JunoLab/Blink.jl/issues/150)
  return haskey(opts, :url) ?
    Window(raw_window(a, opts), a, nothing, nothing) :
    Window(a, Page(), opts, async=async)
end

function Window(a::Shell, content::Page, opts::AbstractDict = Dict(); async=false)
  id, callback_cond = Blink.callback!()
  url = Blink.localurl(content) * "?callback=$id"

  # Create the window.
  opts = merge(opts, Dict(:url => url))
  w = Window(raw_window(a, opts), a, content, nothing)

  # Note: we have to use a task here because of the use of Condition throughout
  # the codebase (it might be better to use Channel or Future which are not
  # edge-triggered). We also need to initialize this after the Window
  # constructor because we have to pass the window into the damn function.
  w.inittask = @async try
    initwindow!(w, callback_cond)
  catch exc
    @error(
      "An error occurred while trying to initialize a Blink window!",
      exception=exc,
    )
  end

  if !async
    wait(w)
  end

  return w
end

function initwindow!(w::Window, callback_cond::Condition)
  initresult = wait(callback_cond)
  if isa(initresult, AbstractDict) && get(initresult, "type", "") == "error"
      throw(JSError(
        get(initresult, "name", "unknown"),
        get(initresult, "message", "blank"),
      ))
  end
  initwebio!(w)
end

Window(args...; kwargs...) = Window(shell(), args...; kwargs...)

dot(a::Electron, win::Integer, code; callback = true) =
  js(a, :(withwin($(win), $(jsstring(code)...))),
     callback = callback)

dot(w::Window, code; callback = true) =
  ifelse(callback, dot(shell(w), id(w), code, callback = callback), w)

dot_(args...) = dot(args..., callback = false)

macro dot(win, code)
  :(dot($(esc(win)), $(esc(Expr(:quote, Expr(:., :this, QuoteNode(code)))))))
end

macro dot_(win, code)
  :(dot_($(esc(win)), $(esc(Expr(:quote, Expr(:., :this, QuoteNode(code)))))))
end

# Base.* methods

function Base.wait(w::Window)
  if w.inittask === nothing
    error("Cannot wait() a \"raw\" window (was this window created with a url arg?).")
  end
  return wait(w.inittask)
end

# Window management APIs

"""
    active(window::Window)::Bool
    active(connection)::Bool

Indicates whether the specified `Window` (or `Page`, `shell`, or other internal component)
is currently "active," meaning it has an open connection to its Electron component.

```julia-repl
julia> w = Window();

julia> active(w)
true

julia> close(w)

julia> active(w)
false
```
"""
function active end

active(s::Electron, win::Integer) =
  @js s windows.hasOwnProperty($win)

active(window::Window) = active(shell(window), id(window))

"""
    flashframe!(window::Window, on::Bool=true)

Start or stop "flashing" the window to get the user's attention.

In Windows, this flashes the window frame.
In MacOS, this bounces the app in the Dock.

See the [Electron `flashFrame` documentation](https://github.com/electron/electron/blob/master/docs/api/browser-window.md#winflashframeflag) for details.
"""
# TODO: Maybe rename this to `flash_frame!`
# The "general advice" is that only Base is allowed to define methods that elide
# the underscore (https://github.com/invenia/BlueStyle).
flashframe!(window::Window, on::Bool=true) = @dot_ window flashFrame($on)

# Deprecated
flashframe(window::Window, on::Bool=true) = flashframe!(window, on)

"""
    progress!(window::Window, progress)

Sets progress value in progress bar. Valid range is [0, 1.0]. Remove progress
bar when progress < 0; Change to _indeterminate mode_ when progress > 1.

See the [Electron `setProgressBar` documentation](https://github.com/electron/electron/blob/master/docs/api/browser-window.md#winsetprogressbarprogress-options) for details.
"""
progress!(window::Window, progress) = @dot_ window setProgressBar($progress)

# Deprecated
progress(window::Window, progress=-1) = progress!(win, progress)

"""
    title!(window::Window, title)

Set the window's title.
"""
title!(window::Window, title) = @dot_ window setTitle($title)

# Deprecated
title(window::Window, title) = title!(window, title)

"""
    title(window::Window)

Get the window's title.
"""
title(window::Window) = @dot window getTitle()

"""
    center!(window::Window)

Center a window on the screen.
"""
center!(window::Window) = @dot_ window center()

# Deprecated (and misspelled?)
centre(window::Window) =
  @dot_ window center()

"""
    position!(window, x, y)
    position!(window, position)

Position a window.

This positions the top-left corner of the window to match the given coordinates.
"""
position!(w::Window, x, y) = @dot_ w setPosition($x, $y)
position!(w::Window, pos) = position!(w, pos...)

# Deprecated
position(w::Window, x, y) = position!(w, x, y)

"""
    position(window)

Get the window's position.

This returns a tuple that represents the position of the top-left corner of the
window.
"""
function position(window::Window)
    x, y = Int.(@dot window getPosition())
    return (x, y)
end

"""
    resize!(window::::Window, width, height)
    resize!(window::::Window, dims)

Resize a window to the given dimensions.
"""
function Base.resize!(window::Window, width, height)
    @dot_ window setSize($width, $height)
end
Base.resize!(window::Window, dims) = resize!(window, dims...)

# Deprecated
Base.size(window::Window, width, height) = resize!(window, width, height)

# Deprecated
# This is required for Julia 0.7 due to ambiguity error with a deprecated
# method for Base.size.
function Base.size(window::Window, width::Integer, height::Integer)
    resize!(window, (width, height))
end

"""
    size(window::Window)

Return a tuple with the dimensions of the window.
"""
function Base.size(window::Window)
    width, height = Int.(@dot window getSize())
    return (width, height)
end

# TODO: What's a good !-method for this setter function?
# Maybe `pin!` or `always_on_top!`?
floating(window::Window, flag) =
  @dot_ window setAlwaysOnTop($flag)

floating(window::Window) =
  @dot window isAlwaysOnTop()

loadurl!(window::Window, url) = @dot window loadURL($url)
loadurl(window::Window, url) = loadurl!(win, url)

loadfile!(window::Window, f) = loadurl(win, "file://$f")
loadfile(window::Window, f) = loadfile!(win, f)

"""
    opentools!(window::Window)

Open the Chrome Developer Tools on `win`.

See also: [`closetools`](@ref), [`tools`](@ref)
"""
# TODO: Maybe rename to open_tools!
opentools!(w::Window) = @dot window openDevTools()
opentools(w::Window) = opentools!(w)

"""
    closetools(window::Window)

Close the Chrome Developer Tools on `win` if open.

See also: [`opentools`](@ref), [`tools`](@ref)
"""
closetools!(window::Window) = @dot window closeDevTools()
closetools(window::Window) = closetools!(win)

"""
    tools!(window::Window)

Toggle the Chrome Developer Tools on `win`.

See also: [`opentools`](@ref), [`closetools`](@ref)
"""
tools!(window::Window) = @dot window toggleDevTools()
tools(window::Window) = tools!(win)


"""
    front!(window::Window)

Bring a window to the front of the desktop without focusing it.
"""
front!(window::Window) = @dot window showInactive()
front(window::Window) = front!(window)

"""
    close(window::Window)

Close a window.
"""
Base.close(window::Window) = @dot window close()

# Window content APIs

active(::Nothing) = false

handlers(w::Window) = handlers(w.content)

msg(win::Window, m) = msg(win.content, m)

js(win::Window, s::JSString; callback = true) =
  active(win.content) ? js(win.content, s, callback = callback) :
    dot(win, :(this.webContents.executeJavaScript($(s.s))), callback = callback)

const initcss = """
  <style>html,body{margin:0;padding:0;border:0;text-align:center;}</style>
  """

function loadhtml!(win::Window, html::AbstractString)
  tmp = string(tempname(), ".html")
  open(tmp, "w") do io
    println(io, initcss)
    println(io, html)
  end
  loadfile(win, tmp)
  @async (sleep(1); rm(tmp))
  return
end
loadhtml(win::Window, html::AbstractString) = loadhtml!(win, html)
