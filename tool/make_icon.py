#!/usr/bin/env python3
"""Generate digaudio's launcher icon (1024x1024 PNG).

Concept (vertical, one composite figure):
  - Note head: large green ellipse in the upper area.
  - "DIG" overlaid in bold white caps on the head (the brand, legible at
    every size — "surimpression").
  - Stem: a thick neutral-grey vertical bar dropping from the head — reads
    as the handle of a shovel.
  - Blade: chunky spade pointing down at the bottom — the visual pun.

A single centered vertical figure means the silhouette is recognizable
even at 48 px.

Run:
    python3 tool/make_icon.py

Outputs:
    assets/icon/digaudio_icon.png       (full icon, dark rounded bg)
    assets/icon/digaudio_icon_fg.png    (transparent bg, for Android
                                         adaptive-icon foreground layer)
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
BG = (10, 10, 11, 255)             # #0A0A0B  digaudio dark
ACCENT = (30, 215, 96, 255)         # #1ED760  brand accent
SHOVEL = (224, 228, 234, 255)       # cool light metal
SHOVEL_DARK = (138, 146, 160, 255)  # rim / depth
TEXT = (255, 255, 255, 255)
FONT_PATH = "/usr/share/fonts/truetype/open-sans/OpenSans-ExtraBold.ttf"

CX = SIZE // 2


def rounded_square(size: int, radius: int, fill) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, size, size], radius=radius, fill=fill)
    return img


def draw_note_head(img: Image.Image) -> tuple[int, int]:
    """Filled green tilted ellipse — reads as a music note head. Returns the
    bottom-center coordinate (used as the stem attach point)."""
    head_w, head_h = 640, 360
    head_top = 110
    # Render the ellipse on a separate layer then rotate ~-10° for a musical
    # lean before compositing back into the canvas.
    layer = Image.new("RGBA", (head_w + 40, head_h + 40), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([20, 20, head_w + 20, head_h + 20], fill=ACCENT)
    layer = layer.rotate(-10, resample=Image.BICUBIC, expand=True)
    x = CX - layer.width // 2
    y = head_top - 20
    img.alpha_composite(layer, (x, y))
    return (CX, y + layer.height - 50)  # bottom-center of the visual head


def draw_dig_text(img: Image.Image, head_center_y: int):
    """'DIG' in bold white caps overlaid on the note head."""
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_PATH, 260)
    text = "DIG"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (SIZE - tw) // 2 - bbox[0]
    y = head_center_y - th // 2 - bbox[1]
    # Soft shadow for legibility
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x + 4, y + 8), text, font=font, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(shadow)
    ImageDraw.Draw(img).text((x, y), text, font=font, fill=TEXT)


def draw_handle_and_blade(img: Image.Image, head_bottom: tuple[int, int]):
    """Thick metal stem dropping from the head, ending in a spade-shaped
    blade pointing down. Drawn as a single silhouette so it reads as one
    connected object at small sizes."""
    draw = ImageDraw.Draw(img)
    cx, top_y = head_bottom

    # ---- Handle (vertical bar) --------------------------------------------
    handle_w = 60
    handle_bottom = 720
    draw.rounded_rectangle(
        [cx - handle_w // 2, top_y - 10, cx + handle_w // 2, handle_bottom],
        radius=14, fill=SHOVEL,
    )
    # Eighth-note flag attached to the upper handle (right side) — small,
    # green, so the figure unambiguously reads as a note even at 48 px.
    flag_top = top_y + 10
    flag_pts = [
        (cx + handle_w // 2 - 2,  flag_top),
        (cx + handle_w // 2 + 130, flag_top + 30),
        (cx + handle_w // 2 + 100, flag_top + 110),
        (cx + handle_w // 2 - 2,  flag_top + 60),
    ]
    draw.polygon(flag_pts, fill=ACCENT)
    # Ferrule (metal collar at the handle/blade joint, slightly darker)
    draw.rounded_rectangle(
        [cx - 90, handle_bottom - 22, cx + 90, handle_bottom + 30],
        radius=10, fill=SHOVEL_DARK,
    )

    # ---- Blade (spade) ----------------------------------------------------
    blade_top = handle_bottom + 18
    blade_w = 420
    blade_tip_y = 940
    # Spade polygon: rectangular top, tapering to a point
    pts = [
        (cx - blade_w / 2, blade_top),
        (cx + blade_w / 2, blade_top),
        (cx + blade_w / 2, blade_top + 90),
        (cx + blade_w / 2 - 28, blade_tip_y - 40),
        (cx, blade_tip_y),
        (cx - blade_w / 2 + 28, blade_tip_y - 40),
        (cx - blade_w / 2, blade_top + 90),
    ]
    draw.polygon(pts, fill=SHOVEL)
    # Bottom rim shadow for depth
    rim_pts = [
        (cx - blade_w / 2, blade_top + 130),
        (cx - blade_w / 2 + 28, blade_tip_y - 40),
        (cx, blade_tip_y),
        (cx + blade_w / 2 - 28, blade_tip_y - 40),
        (cx + blade_w / 2, blade_top + 130),
        (cx + blade_w / 2, blade_top + 160),
        (cx + blade_w / 2 - 28, blade_tip_y - 18),
        (cx, blade_tip_y + 12),
        (cx - blade_w / 2 + 28, blade_tip_y - 18),
        (cx - blade_w / 2, blade_top + 160),
    ]
    draw.polygon(rim_pts, fill=SHOVEL_DARK)


def compose(with_bg: bool) -> Image.Image:
    if with_bg:
        canvas = rounded_square(SIZE, radius=180, fill=BG)
    else:
        canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    head_bottom = draw_note_head(canvas)
    draw_dig_text(canvas, head_center_y=head_bottom[1] - 190)
    draw_handle_and_blade(canvas, head_bottom)
    return canvas


def main():
    compose(with_bg=True).save("assets/icon/digaudio_icon.png", "PNG")
    compose(with_bg=False).save("assets/icon/digaudio_icon_fg.png", "PNG")
    print(f"OK: assets/icon/digaudio_icon.png ({SIZE}x{SIZE})")
    print(f"OK: assets/icon/digaudio_icon_fg.png ({SIZE}x{SIZE}, transparent bg)")


if __name__ == "__main__":
    main()
