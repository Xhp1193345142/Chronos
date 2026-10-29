"""Generate the simple Chronos app mark at every platform icon size.

Requires Pillow: python3 -m pip install Pillow
Run from any directory: python3 tools/generate_icons.py
"""

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
BASE_SIZE = 1024
BACKGROUND = "#0B1020"
ACCENT = "#A7F070"


def base_icon() -> Image.Image:
    image = Image.new("RGB", (BASE_SIZE, BASE_SIZE), BACKGROUND)
    draw = ImageDraw.Draw(image)
    center = BASE_SIZE / 2
    radius = 314
    stroke = 102
    bounds = (
        center - radius,
        center - radius,
        center + radius,
        center + radius,
    )

    # An open clock ring forms a subtle C for Chronos.
    draw.arc(bounds, start=36, end=324, fill=ACCENT, width=stroke)
    for angle in (36, 324):
        radians = math.radians(angle)
        x = center + radius * math.cos(radians)
        y = center + radius * math.sin(radians)
        draw.ellipse(
            (x - stroke / 2, y - stroke / 2, x + stroke / 2, y + stroke / 2),
            fill=ACCENT,
        )

    draw.line((center, center, center + 116, center - 156),
              fill=ACCENT, width=77)
    draw.ellipse((center - 45, center - 45, center + 45, center + 45),
                 fill=ACCENT)
    return image


def save(icon: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    icon.resize((size, size), Image.Resampling.LANCZOS).save(path, optimize=True)


def main() -> None:
    icon = base_icon()
    ios_dir = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((ios_dir / "Contents.json").read_text())
    for item in contents["images"]:
        filename = item.get("filename")
        if not filename:
            continue
        points = float(item["size"].split("x")[0])
        scale = int(item["scale"].removesuffix("x"))
        save(icon, ios_dir / filename, round(points * scale))

    android = ROOT / "android/app/src/main/res"
    for density, size in {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96,
        "xxhdpi": 144, "xxxhdpi": 192,
    }.items():
        save(icon, android / f"mipmap-{density}/ic_launcher.png", size)

    web = ROOT / "web"
    save(icon, web / "favicon.png", 64)
    for size in (192, 512):
        save(icon, web / f"icons/Icon-{size}.png", size)
        save(icon, web / f"icons/Icon-maskable-{size}.png", size)

    save(icon, ROOT / "docs/brand-icon.png", 512)


if __name__ == "__main__":
    main()
