#!/usr/bin/env bash
# SpaceRanger for the PlayStation 5 - copy the built title folder to the console over FTP.
#
#   ps5/tools/deploy.sh
#
# Uploads dist/<TITLE_ID>/ to /data/homebrew/<TITLE_ID>/ through PS5_Vulkan's
# tools/deploy-title-folder.py, which reads the console's address from
# PS5_Vulkan's .env (PS5_HOST, FTP_PORT=2121). Files already there and
# unchanged are skipped; eboot.bin is always sent. Your ROM and the game's
# settings and saves (spaceranger-config/) are never touched.
#
# After the PS5 ReXGlue Template's tools/deploy.sh (Mihawk, KongaTime).
#
# SPDX-License-Identifier: MIT
set -euo pipefail
ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$ps5/sce_sys/param.json")
[[ -d $root/dist/$title_id ]] || { echo "no dist/$title_id: run ps5/tools/build.sh first" >&2; exit 2; }
exec python3 "$vulkan/tools/deploy-title-folder.py" --always eboot.bin "$root/dist/$title_id" "$@"
