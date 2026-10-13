#!/usr/bin/env bash
# SpaceRanger for the PlayStation 5 - SDL2 and FreeType, built for the console.
#
#   ps5/tools/setup-libs.sh SDK
#
# Fetches each at its pinned release into .deps/src, builds it with the
# payload SDK's toolchain and installs it into .deps/native/<name>, where
# ps5/cmake/ps5.cmake finds it. A library already built at its pin (and, for
# SDL2, with the same patch and drivers) is left alone.
#
#   SDL2      release-2.32.10, with ps5/patches/sdl2.patch and the console's
#             video, audio and joystick drivers from ps5/sdl2
#   FreeType  VER-2-13-3, alone (no zlib, PNG, HarfBuzz or Brotli)
#
# SPDX-License-Identifier: MIT
set -euo pipefail
sdk=${1:?usage: setup-libs.sh SDK}
ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
src=$root/.deps/src
work=$root/.deps/work
native=$root/.deps/native
mkdir -p "$src" "$work" "$native"
generator=(-G Ninja)
toolchain=(-DCMAKE_TOOLCHAIN_FILE="$sdk/toolchain/prospero.cmake" -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_VERBOSE_MAKEFILE=OFF)

checkout() { # dir url tag
    if [[ ! -d $1/.git ]]; then
        git clone -q --depth 1 -b "$3" "$2" "$1"
    elif [[ $(git -C "$1" describe --tags --exact-match 2>/dev/null) != "$3" ]]; then
        git -C "$1" fetch -q --depth 1 origin "refs/tags/$3:refs/tags/$3"
        git -C "$1" checkout -q -f "$3"
    fi
}

# --- SDL2 ---------------------------------------------------------------------
sdl_tag=release-2.32.10
sdl_stamp="$sdl_tag $(cat "$ps5/patches/sdl2.patch" "$ps5"/sdl2/*.c | sha256sum | cut -d' ' -f1)"
if [[ ! -f $native/sdl2/.ps5-sdl2 || $(<"$native/sdl2/.ps5-sdl2") != "$sdl_stamp" ]]; then
    echo "==> [sdl2] $sdl_tag with the console's drivers" >&2
    checkout "$src/sdl2" https://github.com/libsdl-org/SDL.git "$sdl_tag"
    git -C "$src/sdl2" checkout -q -f HEAD -- .
    git -C "$src/sdl2" clean -q -fdx
    git -C "$src/sdl2" apply --whitespace=nowarn "$ps5/patches/sdl2.patch"
    mkdir -p "$src/sdl2/src/video/ps5" "$src/sdl2/src/audio/ps5" "$src/sdl2/src/joystick/ps5"
    cp "$ps5/sdl2/SDL_ps5video.c" "$src/sdl2/src/video/ps5/"
    cp "$ps5/sdl2/SDL_ps5audio.c" "$src/sdl2/src/audio/ps5/"
    cp "$ps5/sdl2/SDL_ps5joystick.c" "$src/sdl2/src/joystick/ps5/"
    rm -rf "$work/sdl2-build" "$native/sdl2"
    # Off: what the console does not have. Haptic stays on (its dummy driver):
    # SpaceRanger asks SDL_Init for it.
    cmake -S "$src/sdl2" -B "$work/sdl2-build" "${generator[@]}" "${toolchain[@]}" \
        -DCMAKE_INSTALL_PREFIX="$native/sdl2" -DSDL_PS5_PLATFORM_DIR="$ps5/src" \
        -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF -DSDL2_DISABLE_SDL2MAIN=ON \
        -DSDL_X11=OFF -DSDL_WAYLAND=OFF -DSDL_KMSDRM=OFF -DSDL_OPENGL=OFF -DSDL_OPENGLES=OFF \
        -DSDL_VULKAN=OFF -DSDL_RENDER=OFF -DSDL_OFFSCREEN=OFF -DSDL_DIRECTFB=OFF -DSDL_RPI=OFF \
        -DSDL_VIVANTE=OFF -DSDL_OSS=OFF -DSDL_ALSA=OFF -DSDL_JACK=OFF -DSDL_PIPEWIRE=OFF \
        -DSDL_PULSEAUDIO=OFF -DSDL_SNDIO=OFF -DSDL_ESD=OFF -DSDL_ARTS=OFF -DSDL_NAS=OFF \
        -DSDL_FUSIONSOUND=OFF -DSDL_DISKAUDIO=OFF -DSDL_DUMMYAUDIO=ON -DSDL_DUMMYVIDEO=ON \
        -DSDL_HIDAPI=OFF -DSDL_LIBUDEV=OFF -DSDL_DBUS=OFF -DSDL_IBUS=OFF -DSDL_LOADSO=OFF \
        -DSDL_SENSOR=OFF -DSDL_HAPTIC=ON -DSDL_POWER=OFF -DSDL_RPATH=OFF -DSDL_LIBSAMPLERATE=OFF \
        -DSDL_SYSTEM_ICONV=OFF -DSDL_LIBICONV=OFF > "$work/sdl2-configure.log" 2>&1 ||
        { tail -30 "$work/sdl2-configure.log" >&2; exit 1; }
    cmake --build "$work/sdl2-build" > "$work/sdl2-build.log" 2>&1 ||
        { grep -E "error|FAILED" "$work/sdl2-build.log" | head -20 >&2; exit 1; }
    cmake --install "$work/sdl2-build" > /dev/null
    echo "$sdl_stamp" > "$native/sdl2/.ps5-sdl2"
fi

# --- FreeType -----------------------------------------------------------------
ft_tag=VER-2-13-3
if [[ ! -f $native/freetype/.ps5-freetype || $(<"$native/freetype/.ps5-freetype") != "$ft_tag" ]]; then
    echo "==> [freetype] $ft_tag" >&2
    checkout "$src/freetype" https://github.com/freetype/freetype.git "$ft_tag"
    rm -rf "$work/freetype-build" "$native/freetype"
    cmake -S "$src/freetype" -B "$work/freetype-build" "${generator[@]}" "${toolchain[@]}" \
        -DCMAKE_INSTALL_PREFIX="$native/freetype" -DBUILD_SHARED_LIBS=OFF \
        -DFT_DISABLE_ZLIB=ON -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_HARFBUZZ=ON \
        -DFT_DISABLE_BROTLI=ON > "$work/freetype-configure.log" 2>&1 ||
        { tail -30 "$work/freetype-configure.log" >&2; exit 1; }
    cmake --build "$work/freetype-build" > "$work/freetype-build.log" 2>&1 ||
        { grep -E "error|FAILED" "$work/freetype-build.log" | head -20 >&2; exit 1; }
    cmake --install "$work/freetype-build" > /dev/null
    echo "$ft_tag" > "$native/freetype/.ps5-freetype"
fi
echo "$native"
