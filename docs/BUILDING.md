# Building SpaceRanger

The build is Windows-only for now, and some scripts still assume the project
lives at `C:\SpaceRanger`. Clone or copy the repository there.

Nothing derived from the ROM is in this repository. You generate the
recompiled code from your own ROM, so every build needs one.

## Requirements

- Windows 10/11 x64
- Visual Studio 2022 with the "Desktop development with C++" workload
- CMake 3.20 or newer and Git
- Python 3.11 or newer (`tomllib` is used), installed as a virtual environment
  at `.venv` (`python -m venv .venv`)

## 1. ROM

Copy your Toy Story 2 (N64, USA) ROM to `rom/baserom.us.rev0.z64`.

## 2. Dependencies

Dependencies are upstream repositories plus SpaceRanger patches.
`patches/deps/MANIFEST.md` lists each one's upstream URL, the base commit, and
its patch:

```powershell
git clone https://github.com/rt64/rt64 deps/rt64
git -C deps/rt64 checkout <base commit>
git -C deps/rt64 submodule update --init --recursive
git -C deps/rt64 apply ../../patches/deps/deps_rt64.patch
```

Repeat the same steps for `deps/rt64/src/contrib/plume`,
`deps/N64ModernRuntime` (and its `N64Recomp` submodule),
`deps/RecompFrontend`, and `tools/N64Recomp`.

## 3. Recompile the game code

Build N64Recomp (and RSPRecomp) from `tools/N64Recomp` into
`build/N64Recomp/Release`. Then run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_overlays_pass10.ps1
```

The script audits the ROM against the function map in `config/`, then writes
the recompiled C into `generated/<run id>`. Copy that folder to
`RecompiledFuncs/`.

Generate the audio microcode with RSPRecomp from `rsp/ts2_audio.toml`; it writes
`rsp/ts2_aspMain.cpp`.

## 4. Build

```powershell
cmake -S . -B build-native -G "Visual Studio 17 2022" -A x64
cmake --build build-native --config Release --target spaceranger
```

The game is `build-native/Release/SpaceRanger.exe`. To make a player zip without
ROM data, run `tools/package_release.ps1`. It packages the exe as
`SpaceRanger.exe` inside a `SpaceRanger` folder.

## Linux

The same sources build on Linux with clang (tested with clang 20 on Ubuntu
24.04). RT64 draws through SDL's Vulkan surface there. Packages: `cmake`,
`ninja-build`, `clang-20`, `libsdl2-dev`, `libgtk-3-dev` (RT64's file
dialog) and `libfreetype-dev`.

```bash
tools/setup_deps.sh                                   # step 2: every dependency, patched
cmake -S tools/N64Recomp -B build/N64Recomp -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/N64Recomp                         # N64Recomp and RSPRecomp
# step 3 with your ROM, or for a build that cannot run the game:
tools/make_skeleton_recomp.sh                         # ROM-free skeleton, NOP bodies
cmake -S . -B build-linux -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang-20 -DCMAKE_CXX_COMPILER=clang++-20
cmake --build build-linux --target spaceranger
```

`tools/make_skeleton_recomp.sh` runs the recompilers on an all-zero image
with the project's own config, so the generated tree has every function,
overlay and hook of the real one and compiles and links the same way, but
contains no game code. It is for checking that the program builds (Linux, the
PS5) without a ROM; it does not run the game.

Changes to a dependency are committed on its `spaceranger` branch (which
`tools/setup_deps.sh` creates) and exported with `tools/export_dep_patches.sh`.

The Stage61 harness in `src/stage79_first_vi_audio_wakeup.cpp`, which
`main()` no longer calls, uses Windows APIs and is built on Windows only
(`TS2_STAGE61_HARNESS`).

## Testing tools

- `TS2_INPUT_RECORD=<file>` records controller input, frame-tagged.
- `TS2_INPUT_REPLAY=<file>` plays a recording back exactly, frame by frame.
- `tools/replay_test.ps1` runs a replay with timing logs.
