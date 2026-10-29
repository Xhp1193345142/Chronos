"""Resize the selected Chronos app icon for every platform.

Requires Pillow: python3 -m pip install Pillow
Run from any directory: python3 tools/generate_icons.py
"""

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/chronos-icon-source.png"


def base_icon() -> Image.Image:
    return Image.open(SOURCE).convert("RGB")


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
