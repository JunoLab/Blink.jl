import BinDeps

rm′(f) = (isdir(f) || isfile(f)) && rm(f, recursive = true)

const version = "4.0.4"

folder() = normpath(joinpath(@__FILE__, "../../../deps"))

@static if Sys.isapple()
    uninstall() = map(rm′, filter(x -> !endswith(x, "build.jl"), readdir(folder())))
else
    uninstall() = rm′(joinpath(folder(), "atom"))
end

isinstalled() = Sys.isapple() ?
    isfile(joinpath(folder(), "version")) :
    isdir(joinpath(folder(), "atom"))


function install()
  dir = folder()
  if Sys.isapple()
    _icons = normpath(joinpath(@__FILE__, "../../../res/julia-icns.icns"))
  end
  !isdir(dir) && mkpath(dir)
  uninstall()
  cd(dir) do
    download(x) = run(BinDeps.download_cmd(x, basename(x)))

    download("https://raw.githubusercontent.com/JuliaLang/julia-logo-graphics/master/images/julia-logo-color.png")

    if Sys.isapple()
      file = "electron-v$version-darwin-x64.zip"
      download("https://github.com/electron/electron/releases/download/v$version/$file")
      run(`unzip -q $file`)
      rm(file)
      if isdir("Julia.app") # Issue # 178
          rm("Julia.app", recursive=true)
      end
      run(`mv Electron.app Julia.app`)
      run(`mv Julia.app/Contents/MacOS/Electron Julia.app/Contents/MacOS/Julia`)
      run(`sed -i.bak 's/Electron/Julia/' Julia.app/Contents/Info.plist`)
      run(`cp $_icons Julia.app/Contents/Resources/electron.icns`)
      run(`touch Julia.app`)  # Apparently this is necessary to tell the OS to double-check for the new icons.
    end

    if Sys.iswindows()
      arch = Int == Int64 ? "x64" : "ia32"
      file = "electron-v$version-win32-$arch.zip"
      download("https://github.com/electron/electron/releases/download/v$version/$file")
      try
        run(BinDeps.unpack_cmd(file, "atom", ".zip", nothing))
      catch e
        if e isa Base.IOError && e.code == Base.UV_ENOENT # No such file or directory
          error("Unable to find 7z.exe. Try running `make win-extras` if you built Julia from source.")
        else
          rethrow(e)
        end
      finally
        rm(file)
      end
    end

    if Sys.islinux()
      arch = Int == Int64 ? "x64" : "ia32"
      file = "electron-v$version-linux-$arch.zip"
      download("https://github.com/electron/electron/releases/download/v$version/$file")
      run(`unzip -q $file -d atom`)
      rm(file)
    end
  end
end
