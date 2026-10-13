#!/usr/bin/env python3
"""SpaceRanger for the PlayStation 5 - the home-screen art, kept out of git.

    python3 ps5/tools/title-art.py

The art is usually the game's own (its cover, its key art), so like the ROM it
stays on the machine that builds the title: ps5/title-art/ is ignored by git,
and ps5/tools/link-title.sh lays its sce_sys/ over ps5/sce_sys/ in the title
folder. Put the sources there, run this, and build:

- title-art/icon-source.*        -> sce_sys/icon0.png, 512x512
- title-art/background-source.*  -> sce_sys/pic0.dds and pic1.dds, the
  background the home screen shows behind the title, 3840x2160, as the console
  takes it: DDS with a DX10 header, BC7_UNORM, one level, straight alpha

A background wider than 16:9 (a banner) is not cropped to fill the screen: it
is scaled to the screen's width, set on the bottom edge, and the space above
is filled with the colour of its top rows, blended into it. A taller one is
scaled to cover the screen, centred.

Without title-art/, the title keeps the project's own icon (ps5/sce_sys/
icon0.png, from make-title-art.py) and the shell's plain background.

The console keeps the art it read when the title was registered
(ShadowMountPlus registers a /data/homebrew title once), so changing sce_sys/
in place does not show on the home screen: upload a folder named after the
title ID holding only the new sce_sys/, with ps5upload, overriding the
installed title, and it registers again with the new art.

Needs Pillow and etcpak (pip install etcpak).

From the PS5 ReXGlue Template's tools/title-art.py (KongaTime).
SPDX-License-Identifier: MIT
"""
import struct
import sys
from pathlib import Path

import etcpak
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "ps5" / "title-art"
SCE_SYS = ART / "sce_sys"
WIDTH, HEIGHT = 3840, 2160
FEATHER = 160  # rows over which a banner fades into the fill above it


def source(stem):
    found = sorted(ART.glob(stem + ".*"))
    if not found:
        sys.exit(f"title-art.py: no {ART / stem}.* (a .png, .jpg or .webp)")
    return found[0]


def cover(image, width, height):
    """Scaled to fill width x height, the overflow cut evenly from both sides."""
    scale = max(width / image.width, height / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


def banner(image, width, height):
    """A wide image at the screen's width on its bottom edge, the sky extended up."""
    scaled = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
    top = height - scaled.height
    # The colour of the banner's top rows, averaged across them, fills the space
    # above: their grain stretched upwards would show as streaks.
    band = scaled.crop((0, 0, width, 8)).resize((1, 1), Image.BOX).getpixel((0, 0))
    canvas = Image.new("RGB", (width, height), band)
    canvas.paste(scaled, (0, top))
    # The banner's top edge faded into the fill
    fill = Image.new("RGB", (width, FEATHER), band)
    edge = scaled.crop((0, 0, width, FEATHER))
    ramp = Image.linear_gradient("L").resize((width, FEATHER))
    canvas.paste(Image.composite(edge, fill, ramp), (0, top))
    return canvas


def background(image):
    if image.width * HEIGHT > image.height * WIDTH:
        return banner(image, WIDTH, HEIGHT)
    return cover(image, WIDTH, HEIGHT)


def dds_bc7(image):
    rgba = image.convert("RGBA")
    blocks = etcpak.compress_bc7(rgba.tobytes(), rgba.width, rgba.height)
    linear_size = (rgba.width // 4) * (rgba.height // 4) * 16
    assert len(blocks) == linear_size
    flags = 0x1 | 0x2 | 0x4 | 0x1000 | 0x20000 | 0x80000  # caps, height, width, pixel format, mip count, linear size
    header = struct.pack("<4sIIIIIII11I", b"DDS ", 124, flags, rgba.height, rgba.width, linear_size, 1, 1, *([0] * 11))
    pixel_format = struct.pack("<II4sIIIII", 32, 0x4, b"DX10", 0, 0, 0, 0, 0)
    caps = struct.pack("<IIIII", 0x1000, 0, 0, 0, 0)
    dx10 = struct.pack("<IIIII", 98, 3, 0, 1, 1)  # BC7_UNORM, 2D, no flags, one image, straight alpha
    return header + pixel_format + caps + dx10 + blocks


def main():
    SCE_SYS.mkdir(parents=True, exist_ok=True)
    icon = cover(Image.open(source("icon-source")).convert("RGB"), 512, 512)
    icon.save(SCE_SYS / "icon0.png", optimize=True)
    print(f"wrote {SCE_SYS / 'icon0.png'}")
    picture = background(Image.open(source("background-source")).convert("RGB"))
    picture.save(ART / "background-preview.png")
    data = dds_bc7(picture)
    for name in ("pic0.dds", "pic1.dds"):
        (SCE_SYS / name).write_bytes(data)
        print(f"wrote {SCE_SYS / name} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
