# SpaceRanger on the PlayStation 5

SpaceRanger builds as a native homebrew title for jailbroken PS5 consoles. The
game code is the same N64Recomp output as on PC. It runs on N64ModernRuntime,
draws with RT64 through Vulkan on RADV (Mesa's AMD driver, from Mihawk's
[PS5_Vulkan](https://github.com/mihawk-99/PS5_Vulkan)), and gets sound and the
DualSense through SDL2 drivers for the console.

> **Status:** the title builds, links and signs. It has **not been run on a
> console yet**. Every PS5-specific path below is untested until it has.

## What it needs

**On the console:** etaHEN (or an equivalent),
[ShadowMountPlus](https://github.com/drakmor/ShadowMountPlus) to list
`/data/homebrew` titles on the home screen, and an FTP server (port 2121).

**To build:** a Linux machine (tested on Ubuntu 24.04), with:
- `clang-20`, `lld-20`, `llvm-20-dev`, `libclang-20-dev`, `libclc-20-dev`,
  `llvm-spirv-20`, `cmake`, `ninja-build`, `meson` (1.4 or later),
  `python3-mako`, `rsync`, `zstd`, `wget` and `unzip`, for RADV;
- Python's `cairosvg` and `Pillow`, only to redraw the home-screen icon.

Beside this repository:

```text
somewhere/
  SpaceRanger/       this repository
  PS5_Vulkan/        https://github.com/KongaTime/PS5_Vulkan
  PS5_Mesa/          https://github.com/KongaTime/PS5_Mesa (PS5_Vulkan's pinned revision)
  PS5_PayloadSDK/    https://github.com/KongaTime/PS5_PayloadSDK
```

These are the same checkouts the
[PS5 ReXGlue Template](https://github.com/KongaTime/PS5_ReXGlueTemplate) uses.
Its `tools/bootstrap.sh` clones and builds them. PS5_Vulkan's own SDK pin
(`b83202b`) lives in Mihawk's fork: `git -C PS5_PayloadSDK remote add mihawk
https://github.com/mihawk-99/PS5_PayloadSDK && git -C PS5_PayloadSDK fetch
mihawk`. Then, in PS5_Vulkan:

```bash
tools/setup-native-dependencies.sh   # its payload SDK and zlib
make                                 # the native tool and libc.prx
tools/build-radv.sh release          # the RADV release archive (about 12 minutes on 4 cores)
```

Where zlib.net is unreachable, the same zlib 1.3.2 tarball (same SHA-256) is
on GitHub at `madler/zlib` releases. Mesa's zlib wrap falls back to GitHub by
itself, but its patch comes from wrapdb.mesonbuild.com. Download
`zlib_1.3.1-1_patch.zip` from the `mesonbuild/wrapdb` GitHub release into
`PS5_Vulkan/.deps/work/radv-src/subprojects/packagecache/` first.

## Build

```bash
tools/setup_deps.sh                  # the dependencies, patched (patches/deps)
cmake -S tools/N64Recomp -B build/N64Recomp -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/N64Recomp
# The recompiled game from your ROM (docs/BUILDING.md step 3), or, for a
# title that starts but cannot run the game, the ROM-free skeleton:
tools/make_skeleton_recomp.sh
ps5/tools/build.sh                   # dist/PPSA99264/
ps5/tools/deploy.sh                  # to /data/homebrew/PPSA99264/ over FTP
```

`ps5/tools/build.sh` does the rest:
1. It installs the payload SDK at the template's pin (`1de8b37`).
2. It builds SDL2 and FreeType for the console into `.deps/native/`.
3. It builds RT64's `file_to_c` for the build machine.
4. It configures `build-ps5/` with the SDK's CMake toolchain and builds the game.

The game's link goes to `ps5/tools/link-title.sh`, which links with RADV, signs
`eboot.bin` and writes the title folder.

## Home-screen art

By default the title uses the project's own icon (`ps5/sce_sys/icon0.png`) and
no background. To use the game's cover and key art instead, put them in
`ps5/title-art/`, which git ignores, and run the script before building:

```bash
mkdir -p ps5/title-art
cp cover.png    ps5/title-art/icon-source.png        # square
cp backdrop.png ps5/title-art/background-source.png  # 16:9, or a wide banner
python3 ps5/tools/title-art.py                       # needs Pillow and etcpak
ps5/tools/build.sh
```

The script writes `ps5/title-art/sce_sys/`: `icon0.png` (512x512), plus
`pic0.dds` and `pic1.dds` (3840x2160 BC7). Those are the backgrounds the home
screen shows when the title is selected and while it launches. A banner wider
than 16:9 is set on the bottom edge, and its sky is extended upward. Keep the
subject on the right, because the shell draws the title name and Play button on
the left. The script also writes `ps5/title-art/background-preview.png` so you
can check the result.

The console keeps the art it read when it registered the title. Copying new
files over `sce_sys/` doesn't change the home screen. To make it pick up the new
art, use ps5upload to upload a `PPSA99264` folder that holds only the new
`sce_sys/`, overriding the installed title.

## Install

1. Copy `dist/PPSA99264/` to the console as `/data/homebrew/PPSA99264/`, with
   `sce_sys/icon0.png` in the first upload. ShadowMountPlus skips a title
   without its icon.
2. Copy your ROM into the same folder: Toy Story 2 (N64, USA), as `.z64`,
   `.n64` or `.v64`, in `/data/homebrew/PPSA99264/` or its `rom/` subfolder.
   A title can only see its own folder. At its first start the game checks the
   ROM and keeps a validated copy in `spaceranger-config/`. That is also where
   settings and saves go.
3. Start **SpaceRanger** from the home screen.

The title screen's **Load ROM** opens no file dialog on the console (there is
none). If the ROM isn't found, copy it over FTP and start the title again.

## How it works

```text
  the game (N64Recomp output, RSPRecomp audio)     RecompiledFuncs/, rsp/
        |
  N64ModernRuntime ... threads, timers, RDRAM      deps/N64ModernRuntime
  RecompFrontend ..... menus (RmlUi), input        deps/RecompFrontend
        |                         |
  RT64 (HLE RDP) ............... SDL2 ............ .deps/native/sdl2
        |                    ps5/sdl2: video (one display), AudioOut, the pad
  plume (Vulkan backend)
        |
  RADV + PS5 winsys, VK_KHR_display                PS5_Mesa, PS5_Vulkan
        |
  PS5 GPU
```

What the console needed, all under `#if defined(__PROSPERO__)` (or `PS5` in
CMake):

- **plume** (`patches/deps/deps_rt64_src_contrib_plume.patch`):
  EdgeOfTimeRecomp's `ps5/patches/plume-ps5.patch`. It makes the swap chain on
  a `VK_KHR_display` surface at the display's 3840x2160 mode nearest 60 Hz, and
  takes Vulkan from RADV's ICD entry point, since there is no loader. Four of
  its six hunks applied to RT64's plume as-is; the other two differed only in
  context.
- **RT64:**
  - the display as the window;
  - no file dialogs (nativefiledialog needs GTK);
  - FreeBSD thread names;
  - `file_to_c` from the build machine when cross-compiling.
- **N64ModernRuntime:**
  - The window handle is the display's size.
  - Thread names use `pthread_set_name_np`.
  - RDRAM is reserved and committed in direct memory through the platform
    layer (`ps5_vrange_reserve`/`ps5_vrange_commit`). A plain `mmap` of its
    512 MiB would be charged to the title's ~448 MiB flexible budget.
- **RecompFrontend:**
  - no file dialogs, folders to open, or native mods;
  - settings in the title folder (`/app0`);
  - the display size as RT64's window.
- **SDL2** (`ps5/sdl2`, `ps5/patches/sdl2.patch`): video, audio and joystick
  drivers ported from [PS5_Dusklight](https://github.com/griches/PS5_Dusklight)'s
  SDL3 drivers (griches).
  - Video gives one display and keeps the window bookkeeping.
  - Audio is an AudioOut port at 48 kHz.
  - Each signed-in user's controller is a game controller with its own
    mapping, reported as a DualSense for PlayStation glyphs.
  - `SDL_GetBasePath` is `/app0/`, and the pref path is `/app0/userdata/`.
- **SpaceRanger** (`src/stage79_first_vi_audio_wakeup.cpp`): `/app0` is the
  game's folder (ROM, config, assets), and the window handle is the display's
  size.
- **The title** (`ps5/`):
  - `ps5/src/platform.c` is Mihawk's platform layer from the PS5 Vulkan
    Template: klog, the splash, the pad, sound, and the exit through the shell.
  - `ps5/src/startup.c` starts it before `main`.
  - `ps5/src/shims.c` answers libc names no module a title loads exports
    (mostly from PS5_Dusklight).
  - `ps5/tools/cc-init-array.sh` (PS5_Dusklight) keeps each unit's
    constructors in source order.
  - `ps5/tools/link-title.sh` is the link, after PS5_Dusklight's and Mihawk's.

## Not yet known

Each of these has only been built, never run on a console:
- that RT64's pipelines and its 4K output run at full speed on the console's GPU;
- that the RDRAM reservation and the frame pacing behave on the console;
- that the SDL2 drivers give the right sound and buttons.

Code mods won't load: a title can't map executable memory the usual way.

Debugging follows the ReXGlue template's PORTING.md section 5. Standard error
goes to klog, prefixed with the title's name. The linked ELF for symbolising a
crash is `build-ps5/SpaceRanger`.

## Credits

- **Mihawk** ([mihawk-99](https://github.com/mihawk-99)): PS5_Vulkan,
  PS5_Mesa, the payload SDK fork and its platform layer, and the PS5 Vulkan
  Template's platform layer and link.
- **griches**: [PS5_Dusklight](https://github.com/griches/PS5_Dusklight). Its
  SDL drivers, link script, init-array launcher and libc shims are the base of
  `ps5/`.
- **KongaTime**: the
  [PS5 ReXGlue Template](https://github.com/KongaTime/PS5_ReXGlueTemplate) and
  [EdgeOfTimeRecomp](https://github.com/KongaTime/EdgeOfTimeRecomp)'s plume PS5
  patch.
- [etaHEN](https://github.com/etaHEN/etaHEN) and
  [ShadowMountPlus](https://github.com/drakmor/ShadowMountPlus) (drakmor).

## Licences

`ps5/` holds files under MIT (`ps5/LICENSE-MIT.txt`), Zlib (the SDL2
drivers, `ps5/sdl2/LICENSE-Zlib.txt`) and GPL-3.0 (the icon script and the
icon, drawn from SpaceRanger's own art). Each source file's header names its
licence.
A built title links the GPL-3.0 platform layer and PS5_Vulkan's tools, and
SpaceRanger itself is GPL-3.0, so a title as distributed is under GPL-3.0.
`licenses/` beside `eboot.bin` holds every part's licence. No game data is in
this repository or in a build: players use their own ROM.
