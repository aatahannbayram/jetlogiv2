"""Launcher icons from the JetLogi J-arrow in jetlogi_logo_white.png."""

from __future__ import annotations

from pathlib import Path

from PIL import Image
import numpy as np


def j_glyph(logo: Image.Image) -> Image.Image:
    arr = np.array(logo.convert("RGBA"))
    alpha = arr[:, :, 3]
    col_ink = (alpha > 160).sum(axis=0)
    row_ink = (alpha > 160).sum(axis=1)
    cols = np.where(col_ink > 8)[0]
    rows = np.where(row_ink > 8)[0]
    minx, maxx = int(cols[0]), int(cols[-1])
    miny, maxy = int(rows[0]), int(rows[-1])
    jw = int((maxx - minx + 1) * 0.155)
    slice_im = logo.crop((minx, miny, minx + jw, maxy + 1))
    sa = np.array(slice_im)[:, :, 3]
    cys, cxs = np.where(sa > 80)
    return slice_im.crop(
        (int(cxs.min()), int(cys.min()), int(cxs.max()) + 1, int(cys.max()) + 1)
    )


def make_square(glyph: Image.Image, size: int, pad: float) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    inner = int(size * (1 - 2 * pad))
    g = glyph.copy()
    g.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    x = (size - g.width) // 2
    y = (size - g.height) // 2
    canvas.paste(g, (x, y), g)
    return canvas.convert("RGB")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    assets = root / "assets" / "images"
    logo = Image.open(assets / "jetlogi_logo_white.png")
    glyph = j_glyph(logo)

    full = make_square(glyph, 1024, 0.18)
    fg = make_square(glyph, 1024, 0.24)
    full.save(assets / "app_icon.png")
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
        mark = make_square(glyph, 512, 0.22)
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

    print("wrote JetLogi app icons")


if __name__ == "__main__":
    main()
