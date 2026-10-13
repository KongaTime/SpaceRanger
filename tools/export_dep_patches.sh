#!/usr/bin/env bash
# Exports each dependency's SpaceRanger changes (upstream base -> current
# "spaceranger" HEAD) to patches/deps and rewrites MANIFEST.md: the bash
# counterpart of tools/export_dep_patches.ps1, with the same output.
#
#   tools/export_dep_patches.sh
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
manifest=$root/patches/deps/MANIFEST.md
rows=()
while read -r dir url base _; do
    path=$root/$dir
    if [[ -n $(git -C "$path" status --porcelain --ignore-submodules=all --untracked-files=no) ]]; then
        echo "$dir has uncommitted changes; commit them first." >&2
        exit 1
    fi
    head=$(git -C "$path" rev-parse HEAD)
    name=${dir//\//_}.patch
    out=$root/patches/deps/$name
    git -C "$path" -c core.autocrlf=false diff --binary --ignore-submodules=all "$base" "$head" > "$out.new"
    # The SpaceRanger commit is a local id: a patch that did not change keeps
    # the row it had, so the manifest changes only with the patches
    if cmp -s "$out.new" "$out"; then
        rm -f -- "$out.new"
        head=$(grep -E "^\| $dir \|" "$manifest" | awk -F'|' '{gsub(/ /,""); print $5}')
    else
        mv -- "$out.new" "$out"
    fi
    rows+=("| $dir | $url | $base | $head |")
    printf '%-34s %s  %s KB\n' "$dir" "${head:0:8}" $(( $(stat -c %s "$out") / 1024 ))
done < <(grep -E '^\| (deps|tools)/' "$manifest" | awk -F'|' '{gsub(/ /,""); print $2, $3, $4}')
{
    printf '%s\n' '# Dependency snapshot manifest' '' \
        'Each dependency is the upstream repository at the base commit plus the' \
        'matching patch in this folder (`git apply` inside that directory).' '' \
        '| directory | upstream | base commit | SpaceRanger commit |' '| --- | --- | --- | --- |'
    printf '%s\n' "${rows[@]}"
} > "$manifest"
