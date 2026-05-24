#!/usr/bin/env python3
"""Produce the Android adaptive-icon foreground from the main icon.

Android's adaptive icon system applies a launcher-supplied mask (round,
squircle, teardrop, …) and crops everything outside a 66%-of-canvas safe
zone. If the source icon goes edge-to-edge, the mask clips visible
content. This script takes `assets/icon/digaudio_icon.png` and produces
`assets/icon/digaudio_icon_fg.png` — the same artwork scaled to ~68% of
the canvas with transparent padding around it, so nothing meaningful gets
cropped on any launcher.

Run after updating the main icon:
    python3 tool/make_adaptive_fg.py
    dart run flutter_launcher_icons    # regenerate platform assets
"""
from PIL import Image

SRC = "assets/icon/digaudio_icon.png"
DST = "assets/icon/digaudio_icon_fg.png"
SIZE = 1024
# 68% leaves a hair of margin beyond the strict 66% safe zone.
INNER = int(SIZE * 0.68)


def main():
    src = Image.open(SRC).convert("RGBA")
    content = src.resize((INNER, INNER), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    offset = (SIZE - INNER) // 2
    canvas.paste(content, (offset, offset), content)
    canvas.save(DST, "PNG")
    print(f"OK: {DST} ({SIZE}x{SIZE}, content {INNER}x{INNER} centered)")


if __name__ == "__main__":
    main()
