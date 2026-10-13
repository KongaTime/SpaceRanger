#!/usr/bin/env python3
"""SpaceRanger for the PlayStation 5 - the home-screen icon.

    python3 ps5/tools/make-title-art.py [OUT_DIR]

Draws sce_sys/icon0.png (512x512, which ShadowMountPlus needs to list the
title) from the project's own launcher art: the space backdrop
(assets/launcher-background.svg) with the wordmark (assets/launcher-logo.svg)
over it. Nothing in it comes from the game. Needs cairosvg and Pillow.

SPDX-License-Identifier: GPL-3.0-only
"""
import io
import os
import sys

import cairosvg
from PIL import Image

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'ps5', 'sce_sys')
assets = os.path.join(root, 'assets')


def render(name, **size):
    png = cairosvg.svg2png(url=os.path.join(assets, name), **size)
    return Image.open(io.BytesIO(png)).convert('RGBA')


# The backdrop at the icon's height, cropped to a square around its middle
backdrop = render('launcher-background.svg', output_height=512)
left = (backdrop.width - 512) // 2
icon = backdrop.crop((left, 0, left + 512, 512))
# The wordmark across the lower part, with a margin
logo = render('launcher-logo.svg', output_width=456)
icon.alpha_composite(logo, ((512 - logo.width) // 2, 512 - logo.height - 40))
os.makedirs(out, exist_ok=True)
icon.convert('RGB').save(os.path.join(out, 'icon0.png'), optimize=True)
print(os.path.join(out, 'icon0.png'))
