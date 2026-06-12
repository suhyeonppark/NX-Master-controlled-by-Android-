"""Generate the launcher icon to match the user's app family (Play Console,
LMPM, STREAM MON): a clean white rounded-square with a single blue glyph in
the centre -- here a power symbol drawn directly in blue, no filled disc.

Run:  python tool/gen_icon.py
"""
import math
import os

from PIL import Image, ImageDraw

WHITE = (255, 255, 255, 255)
BLUE_TOP = (59, 130, 246)     # #3B82F6
BLUE_BOTTOM = (29, 78, 216)   # #1D4ED8

# Android legacy launcher densities -> pixel size.
SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

RES = os.path.join("android", "app", "src", "main", "res")
SS = 8  # supersampling factor for smooth edges


def _vertical_gradient(size: int) -> Image.Image:
    """A square filled with a vertical top->bottom blue gradient."""
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        grad.putpixel(
            (0, y),
            tuple(round(a + (b - a) * t) for a, b in zip(BLUE_TOP, BLUE_BOTTOM)),
        )
    return grad.resize((size, size))


def _power_glyph_mask(s: int, cx: float, cy: float, R: float,
                      stroke: float) -> Image.Image:
    """Alpha mask (L) of a power symbol: a ring open at the top plus a
    vertical bar, centred on (cx, cy). The ring is built from a filled
    annulus so its open ends get clean round caps (PIL's thick ``arc``
    leaves spiky ends)."""
    mask = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(mask)
    half = stroke / 2

    # Annulus: outer disc minus inner disc.
    ro = R + half
    ri = R - half
    d.ellipse([cx - ro, cy - ro, cx + ro, cy + ro], fill=255)
    d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=0)

    # Carve the opening at 12 o'clock (270 deg in PIL) as a wedge.
    gap = 52  # degrees of opening
    start = 270 - gap / 2
    end = 270 + gap / 2
    d.pieslice([cx - ro, cy - ro, cx + ro, cy + ro],
               start=start, end=end, fill=0)

    # Round the two cut ends with circular caps on the centreline.
    for ang in (start, end):
        ex = cx + R * math.cos(math.radians(ang))
        ey = cy + R * math.sin(math.radians(ang))
        d.ellipse([ex - half, ey - half, ex + half, ey + half], fill=255)

    # Vertical bar with rounded ends.
    top = cy - R * 1.30
    bot = cy - R * 0.04
    d.line([cx, top, cx, bot], fill=255, width=int(stroke))
    for y in (top, bot):
        d.ellipse([cx - half, y - half, cx + half, y + half], fill=255)
    return mask


def render(size: int) -> Image.Image:
    s = size * SS
    cx = cy = s / 2

    # White rounded-square background, transparent corners.
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle(
        [0, 0, s - 1, s - 1], radius=int(s * 0.23), fill=WHITE)

    # Blue power glyph drawn straight onto the white tile.
    glyph_mask = _power_glyph_mask(
        s, cx, cy, R=s * 0.245, stroke=s * 0.072)
    blue = _vertical_gradient(s).convert("RGBA")
    img.paste(blue, (0, 0), glyph_mask)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    for density, size in SIZES.items():
        out = os.path.join(RES, f"mipmap-{density}", "ic_launcher.png")
        render(size).save(out)
        print(f"wrote {out} ({size}x{size})")


if __name__ == "__main__":
    main()
