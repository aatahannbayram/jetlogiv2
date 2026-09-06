"""Rasterize the in-app Dijigoo mark (lib/brand.dart) to launcher PNGs."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


def cubic(p0, p1, p2, p3, steps=28):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        pts.append(
            (
                u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1],
            )
        )
    return pts


def mark_paths(s: float, ox: float, oy: float):
    def p(x, y):
        return (ox + x * s, oy + y * s)

    pin = []
    pin += cubic(p(0.50, 0.96), p(0.18, 0.68), p(0.08, 0.46), p(0.08, 0.38))
    pin += cubic(p(0.08, 0.38), p(0.08, 0.16), p(0.26, 0.04), p(0.50, 0.04))
    pin += cubic(p(0.50, 0.04), p(0.74, 0.04), p(0.92, 0.16), p(0.92, 0.38))
    pin += cubic(p(0.92, 0.38), p(0.92, 0.46), p(0.82, 0.68), p(0.50, 0.96))

    d = []
    d.append(p(0.38, 0.22))
    d.append(p(0.38, 0.54))
    d.append(p(0.50, 0.54))
    d += cubic(p(0.50, 0.54), p(0.64, 0.54), p(0.72, 0.48), p(0.72, 0.38))
    d += cubic(p(0.72, 0.38), p(0.72, 0.28), p(0.64, 0.22), p(0.50, 0.22))
    return pin, d


def render(size: int, *, pad: float, bg: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (size, size), bg)
    draw = ImageDraw.Draw(img)
    inner = size * (1 - 2 * pad)
    ox = oy = size * pad
    pin, d = mark_paths(inner, ox, oy)
    draw.polygon(pin, fill=(255, 255, 255))
    draw.polygon(d, fill=bg)
    return img


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    assets = root / "assets" / "images"
    assets.mkdir(parents=True, exist_ok=True)

    full = render(1024, pad=0.18, bg=(0, 0, 0))
    full.save(assets / "app_icon.png")
    fg = render(1024, pad=0.22, bg=(0, 0, 0))
    fg.save(assets / "app_icon_fg.png")

    android = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in android.items():
        dest = root / "android" / "app" / "src" / "main" / "res" / folder
        dest.mkdir(parents=True, exist_ok=True)
        full.resize((px, px), Image.Resampling.LANCZOS).save(dest / "ic_launcher.png")
        fg.resize((px, px), Image.Resampling.LANCZOS).save(
            dest / "ic_launcher_foreground.png"
        )

    ios = root / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, px in ios_sizes.items():
        full.resize((px, px), Image.Resampling.LANCZOS).save(ios / name)

    launch = root / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    if launch.exists():
        mark = render(512, pad=0.22, bg=(0, 0, 0))
        mark.save(launch / "LaunchImage.png")
        mark.resize((256, 256), Image.Resampling.LANCZOS).save(
            launch / "LaunchImage@2x.png"
        )
        mark.resize((384, 384), Image.Resampling.LANCZOS).save(
            launch / "LaunchImage@3x.png"
        )

    macos = root / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    if macos.exists():
        for name, px in {
            "app_icon_16.png": 16,
            "app_icon_32.png": 32,
            "app_icon_64.png": 64,
            "app_icon_128.png": 128,
            "app_icon_256.png": 256,
            "app_icon_512.png": 512,
            "app_icon_1024.png": 1024,
        }.items():
            full.resize((px, px), Image.Resampling.LANCZOS).save(macos / name)

    print("wrote app icons")


if __name__ == "__main__":
    main()
