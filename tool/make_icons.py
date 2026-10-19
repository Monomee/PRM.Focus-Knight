"""Generate the Android launcher + notification icons from the Tiny Swords badges.

    python -m pip install --target <dir> pillow
    PYTHONPATH=<dir> python tool/make_icons.py

App icon: warrior_amethyst badge on the battle-sky teal (adaptive icon + legacy PNGs).
Notification icon: white silhouette of warrior_starter (Android only uses the alpha shape).
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
APP_BADGE = ROOT / "ui/ranks/warrior/warrior_amethyst.png"
NOTIF_BADGE = ROOT / "ui/ranks/warrior/warrior_starter.png"

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
SKY_CENTER, SKY_EDGE = (0x5C, 0xC3, 0xC4), (0x2F, 0x8F, 0x91)
BADGE_SHARE = 0.60  # of the 108dp adaptive canvas; the visible mask is the inner 72dp (0.67)


def scaled(img: Image.Image, size: int) -> Image.Image:
    # Pixel art: nearest when enlarging keeps crisp pixels; Lanczos when shrinking avoids jaggies.
    return img.resize((size, size), Image.NEAREST if size >= img.width else Image.LANCZOS)


def sky(size: int) -> Image.Image:
    """Radial teal gradient, lighter slightly above center (like the mockup)."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    cx, cy, r = size / 2, size * 0.35, size * 0.75
    for y in range(size):
        for x in range(size):
            t = min(1.0, ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / r)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(SKY_CENTER, SKY_EDGE))
    return img


def badge_on(canvas: int, badge: Image.Image, share: float) -> Image.Image:
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    b = scaled(badge, round(canvas * share))
    out.alpha_composite(b, ((canvas - b.width) // 2, (canvas - b.height) // 2))
    return out


DARK_CUTOFF = 60  # outline / visor pixels darker than this become holes, so the helmet stays readable


def silhouette(badge: Image.Image, size: int) -> Image.Image:
    # Alpha-only shape with the dark ink lines carved out (a plain alpha mask is a featureless blob).
    lum = badge.convert("L").point(lambda v: 255 if v > DARK_CUTOFF else 0)
    shape = Image.new("RGBA", badge.size, (255, 255, 255, 0))
    shape.putalpha(Image.composite(badge.getchannel("A"), Image.new("L", badge.size, 0), lum))
    badge = shape
    alpha = badge.getchannel("A")
    crop = badge.crop(alpha.getbbox())
    side = max(crop.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(crop, ((side - crop.width) // 2, (side - crop.height) // 2))
    inner = scaled(square, round(size * 22 / 24))  # 1dp padding each side, per Android guidelines
    white = Image.new("RGBA", inner.size, (255, 255, 255, 0))
    white.putalpha(inner.getchannel("A"))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(white, ((size - inner.width) // 2, (size - inner.height) // 2))
    return out


def main() -> None:
    app = Image.open(APP_BADGE).convert("RGBA")
    notif = Image.open(NOTIF_BADGE).convert("RGBA")

    for name, k in DENSITIES.items():
        mip = RES / f"mipmap-{name}"
        mip.mkdir(exist_ok=True)
        adaptive = round(108 * k)
        badge_on(adaptive, app, BADGE_SHARE).save(mip / "ic_launcher_foreground.png")
        sky(adaptive).save(mip / "ic_launcher_background.png")
        # Android 13 themed icon: same silhouette as the notification icon, inside the safe zone.
        badge_on(adaptive, silhouette(notif, 256), BADGE_SHARE).save(mip / "ic_launcher_monochrome.png")

        # Legacy (pre-Android 8) icon: rounded square, badge a bit larger since nothing is masked.
        legacy = round(48 * k)
        icon = sky(legacy).convert("RGBA")
        icon.alpha_composite(badge_on(legacy, app, 0.86))
        mask = Image.new("L", (legacy, legacy), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, legacy - 1, legacy - 1), radius=round(legacy * 0.22), fill=255)
        icon.putalpha(mask)
        icon.save(mip / "ic_launcher.png")

        drawable = RES / f"drawable-{name}"
        drawable.mkdir(exist_ok=True)
        silhouette(notif, round(24 * k)).save(drawable / "ic_stat_focusknight.png")

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    print("icons written to", RES)


if __name__ == "__main__":
    main()
