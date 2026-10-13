#!/usr/bin/env bash
# Checks out every dependency at the base commit patches/deps/MANIFEST.md names
# and applies its SpaceRanger patch, committed on a "spaceranger" branch so
# tools/export_dep_patches.sh can export later changes. The bash counterpart of
# docs/BUILDING.md step 2, for Linux and the PS5 build.
#
#   tools/setup_deps.sh
#
# A dependency that is already at its SpaceRanger commit is left alone.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest=$root/patches/deps/MANIFEST.md

# Parents before the submodules inside them (rt64 before its plume)
rows=$(grep -E '^\| (deps|tools)/' "$manifest" | awk -F'|' '{gsub(/ /,""); print $2, $3, $4, $5}' |
    awk '{print length($1), $0}' | sort -n | cut -d' ' -f2-)

patch_name() { local dir=$1; dir=${dir//\//_}; echo "$dir.patch"; }

while read -r dir url base mine; do
    path=$root/$dir
    if [[ -d $path/.git || -f $path/.git ]] && git -C "$path" rev-parse -q --verify spaceranger > /dev/null; then
        echo "have    $dir ($(git -C "$path" rev-parse --short spaceranger))"
        continue
    fi
    if [[ ! -e $path/.git ]]; then
        mkdir -p "$path"
        git -C "$path" init -q
        git -C "$path" remote add origin "$url"
        git -C "$path" fetch -q --depth 1 origin "$base"
        git -C "$path" checkout -q FETCH_HEAD
    fi
    [[ $(git -C "$path" rev-parse HEAD) == "$base" ]] || { echo "$dir is not at $base" >&2; exit 1; }
    git -C "$path" submodule update -q --init --recursive --depth 1 ||
        git -C "$path" submodule update -q --init --recursive
    git -C "$path" checkout -q -b spaceranger
    patch=$root/patches/deps/$(patch_name "$dir")
    git -C "$path" apply --whitespace=nowarn "$patch"
    git -C "$path" add -A
    git -C "$path" -c user.name=SpaceRanger -c user.email=spaceranger@localhost \
        commit -q --no-verify -m "SpaceRanger patches (patches/deps/${patch##*/})"
    echo "patched $dir"
done <<< "$rows"
