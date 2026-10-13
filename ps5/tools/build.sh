#!/usr/bin/env bash
# SpaceRanger for the PlayStation 5 - build the title into dist/<TITLE_ID>/.
#
#   ps5/tools/build.sh [ninja arguments]
#
# Needs, beside this repository (docs/PS5.md has the steps):
#   ../PS5_Vulkan       with its RADV release archive, native tool and libc.prx
#                       built (PS5_VULKAN_DIR)
#   ../PS5_PayloadSDK   the payload SDK fork (PS5_PAYLOAD_SDK_FORK)
# and, in this repository, the dependencies (tools/setup_deps.sh) and the
# recompiled game (RecompiledFuncs/ and rsp/ts2_aspMain.cpp, from your ROM;
# tools/make_skeleton_recomp.sh gives a skeleton that builds but cannot run
# the game).
#
# It installs the pinned payload SDK (ps5/tools/setup-sdk.sh), builds SDL2 and
# FreeType for the console (ps5/tools/setup-libs.sh) and file_to_c for this
# machine, configures the build (once) with the SDK's CMake toolchain, which
# brings in ps5/cmake/ps5.cmake, and builds the game, whose link
# (ps5/tools/link-title.sh) writes dist/<TITLE_ID>/.
#
#   PS5_BUILD_DIR   the build tree (default build-ps5)
#
# SPDX-License-Identifier: MIT
set -euo pipefail

ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
build=${PS5_BUILD_DIR:-$root/build-ps5}
ninja=$(command -v ninja || echo "$HOME/.local/bin/ninja")

clang_major=$(clang --version 2> /dev/null | sed -n 's/.*clang version \([0-9]*\).*/\1/p' | head -1)
if [[ -z $clang_major || $clang_major -lt 20 ]] && [[ -d /usr/lib/llvm-20/bin ]]; then
    export PATH=/usr/lib/llvm-20/bin:$PATH
fi
export PS5_CLANG=${PS5_CLANG:-$(command -v clang || true)}

for required in "$root/deps/rt64/CMakeLists.txt" "$root/deps/N64ModernRuntime/CMakeLists.txt" \
        "$root/deps/RecompFrontend/CMakeLists.txt"; do
    [[ -f $required ]] || { echo "no $required: run tools/setup_deps.sh" >&2; exit 2; }
done
for required in "$root/RecompiledFuncs/funcs.h" "$root/rsp/ts2_aspMain.cpp"; do
    [[ -f $required ]] || {
        echo "no $required: recompile the game from your ROM (docs/BUILDING.md), or" \
            "tools/make_skeleton_recomp.sh for a build that cannot run it" >&2
        exit 2
    }
done
grep -q "^SKELETON" "$root/RecompiledFuncs/SOURCE_PASS.txt" 2> /dev/null &&
    echo "ps5/tools/build.sh: RecompiledFuncs/ is the ROM-free skeleton: this title will not run the game" >&2
for required in "$vulkan/.deps/native/radv-release/lib/libvulkan_radeon.ps5.a" \
        "$vulkan/build/host/ps5-native-tool" "$vulkan/runtime/libc.prx"; do
    [[ -e $required ]] || {
        echo "no $required: build PS5_Vulkan first (tools/setup-native-dependencies.sh, make," \
            "tools/build-radv.sh release)" >&2
        exit 2
    }
done

sdk=$(bash "$ps5/tools/setup-sdk.sh")
libs=$(bash "$ps5/tools/setup-libs.sh" "$sdk")
# RT64 runs file_to_c during the build: one for this machine
mkdir -p "$build/host"
if [[ ! -x $build/host/file_to_c || $root/deps/rt64/src/tools/file_to_c/file_to_c.cpp -nt $build/host/file_to_c ]]; then
    c++ -O2 -std=c++17 "$root/deps/rt64/src/tools/file_to_c/file_to_c.cpp" -o "$build/host/file_to_c"
fi

if [[ ! -f $build/build.ninja ]]; then
    cmake -S "$root" -B "$build" -G Ninja -DCMAKE_MAKE_PROGRAM="$ninja" \
        -DCMAKE_TOOLCHAIN_FILE="$sdk/toolchain/prospero.cmake" -DCMAKE_BUILD_TYPE=Release \
        -DPS5_VULKAN_DIR="$vulkan" -DPS5_LIBS_DIR="$libs" -DRT64_FILE_TO_C="$build/host/file_to_c" \
        -DCMAKE_VERBOSE_MAKEFILE=OFF > "$build/configure.log" 2>&1 \
        || { tail -60 "$build/configure.log" >&2; exit 1; }
fi
"$ninja" -C "$build" "${@:-spaceranger}"
