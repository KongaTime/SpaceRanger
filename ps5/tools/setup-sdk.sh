#!/usr/bin/env bash
# SpaceRanger for the PlayStation 5 - the payload SDK the title builds with, at a pinned revision.
#
#   ps5/tools/setup-sdk.sh       install it into .deps/native/ps5-payload-sdk (once a revision);
#                                prints its path
#
# The SDK is the fork with the PS5 platform layer (libps5platform.a,
# include/ps5platform), ../PS5_PayloadSDK (or PS5_PAYLOAD_SDK_FORK): the
# upstream release with the fork's headers and platform layer installed over it.
# The pinned revision is exported with git archive, so a build never depends on
# the fork's working tree. RADV's archive, its link recipe and the packaging
# tools stay PS5_Vulkan's.
#
# After Mihawk's PS5 Vulkan Template (tools/setup-sdk.sh).
#
# SPDX-License-Identifier: MIT
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cache="$root/.deps/native"
sdk="$cache/ps5-payload-sdk"
sdk_fork="${PS5_PAYLOAD_SDK_FORK:-$root/../PS5_PayloadSDK}"
# 1de8b37 (KongaTime/PS5_PayloadSDK): the pin of the PS5 ReXGlue Template, which
# Spider-Man: Edge of Time shipped with; the platform layer's pathconf, sbrk and
# localeconv in the C locale.
sdk_revision=1de8b37d583de476ad07cde9a0d562b75fb1be8f

if [[ ! -f $sdk/.ps5-sdk-revision || $(<"$sdk/.ps5-sdk-revision") != "$sdk_revision" ]]; then
    git -C "$sdk_fork" cat-file -e "$sdk_revision^{commit}" 2>/dev/null || {
        echo "the payload SDK fork at $sdk_fork does not have $sdk_revision" >&2
        echo "  git clone https://github.com/KongaTime/PS5_PayloadSDK $sdk_fork" >&2
        exit 2
    }
    mkdir -p "$cache"
    sdk_tree=$(mktemp -d)
    git -C "$sdk_fork" archive "$sdk_revision" | tar -x -C "$sdk_tree"
    bash "$sdk_tree/platform/tools/setup-sdk.sh" "$sdk" "$sdk_revision" "$cache" >&2
    rm -rf -- "$sdk_tree"
fi
[[ -x $sdk/bin/prospero-lld && -d $sdk/target/include ]] || { echo "the pinned PS5 payload SDK is incomplete" >&2; exit 2; }
echo "$sdk"
