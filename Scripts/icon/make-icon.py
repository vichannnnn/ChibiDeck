#!/usr/bin/env python3
"""Builds Resources/ChibiDeck.icns (macOS 15 tile) and Resources/ChibiDeck.icon (macOS 26 Icon Composer package): a night scene — Mage standing behind the Xeneon Edge
(the wide strip display, screen lit in the theme accent), a crescent moon and a few pixel stars, on a night-sky
gradient inside the macOS icon squircle. Pillow + iconutil. Rerun when the Mage sprite or the theme changes.
  --png <path>   write only a 1024 px PNG preview there instead of the .icns."""
import json, subprocess, sys, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts/mascots"))
import render  # noqa: E402

OUT_PNG = Path(sys.argv[sys.argv.index("--png") + 1]) if "--png" in sys.argv else None

sprite = json.loads((ROOT / "Sources/PanelCore/Resources/Mascots/mage.json").read_text())
theme = json.loads((ROOT / "Sources/PanelCore/Resources/Themes/midnight-witch.json").read_text())
SIZE = 1024
bg, card, line, accent, text = (render.rgba(theme[k]) for k in ("background", "card", "line", "accent", "text"))

def compose(inset_fraction):
    """The scene on a 1024 canvas. `inset_fraction` 0.10 is the macOS icon grid (the .icns tile for macOS 15);
    0 fills the canvas edge to edge for the Icon Composer layer (macOS 26 masks it to its own squircle and treats
    an icon with a transparent margin as legacy: shrunk inside a grey glass tile — verified 2026-09-09)."""
    inset = int(SIZE * inset_fraction)
    tile = SIZE - 2 * inset
    radius = int(tile * 0.225)
    x0, y0, x1, y1 = inset, inset, SIZE - inset - 1, SIZE - inset - 1
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=255)

    def blurred(draw_fn, blur):
        layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        draw_fn(ImageDraw.Draw(layer))
        return layer.filter(ImageFilter.GaussianBlur(blur))

    # 1. night sky: bluer at the top, the theme background near the horizon
    top = (0x23, 0x21, 0x4E, 255)
    art = Image.new("RGBA", (SIZE, SIZE), bg)
    grad = Image.new("RGBA", (1, tile))
    for i in range(tile):
        t = (i / (tile - 1)) ** 1.3
        grad.putpixel((0, i), tuple(int(top[c] * (1 - t) + bg[c] * t) for c in range(3)) + (255,))
    art.paste(grad.resize((tile, tile)), (x0, y0))

    # 2. crescent moon (pixel-stepped: drawn at 1/8 scale and scaled up with nearest neighbour) and a few stars
    moon_small = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    md = ImageDraw.Draw(moon_small)
    md.ellipse([2, 2, 21, 21], fill=text)
    md.ellipse([7, 0, 26, 19], fill=(0, 0, 0, 0))
    moon = moon_small.resize((24 * 7, 24 * 7), Image.NEAREST)
    art.alpha_composite(blurred(lambda d: d.ellipse([x1 - 260, y0 + 10, x1 - 20, y0 + 250], fill=text[:3] + (60,)), 60))
    art.alpha_composite(moon, (x1 - 230, y0 + 40))
    d = ImageDraw.Draw(art)
    px = 6
    for sx, sy, big in [(210, 200, True), (330, 130, False), (470, 250, False), (150, 380, False), (620, 170, True), (860, 420, False)]:
        if big:
            d.rectangle([sx - px * 2, sy - px // 2, sx + px * 2, sy + px // 2], fill=text)
            d.rectangle([sx - px // 2, sy - px * 2, sx + px // 2, sy + px * 2], fill=text)
        else:
            d.rectangle([sx - px // 2, sy - px // 2, sx + px // 2, sy + px // 2], fill=text[:3] + (200,))

    # 3. Mage (cruise pose) at an integer scale, standing behind the display: the bottom of the sprite goes behind it
    frame = render.frame_image(sprite, sprite["tiers"]["cruise"][0])
    frame = frame.crop(frame.getbbox())
    scale = 11
    big = frame.resize((frame.width * scale, frame.height * scale), Image.NEAREST)
    mx, my = (SIZE - big.width) // 2 - 30, y1 - big.height - 30
    art.alpha_composite(blurred(lambda d: d.ellipse([mx - 60, my + 40, mx + big.width + 60, my + big.height - 60], fill=accent[:3] + (60,)), 120))
    art.alpha_composite(big, (mx, my))

    # 4. the Edge: a wide, thin display in front of her, screen lit with the accent, glow spilling onto the sky
    dt, db = y1 - 250, y1 - 70
    dl, dr = x0 + 70, x1 - 70
    bezel = 14
    art.alpha_composite(blurred(lambda d: d.rectangle([dl + 30, dt - 30, dr - 30, db + 30], fill=accent[:3] + (110,)), 50))
    d = ImageDraw.Draw(art)
    d.rounded_rectangle([dl, dt, dr, db], radius=26, fill=(0x1A, 0x1A, 0x22, 255), outline=(0x2C, 0x2C, 0x38, 255), width=3)
    # screen: the panel in miniature on a dim accent gradient — mascot tile and clock on the left, limit bars and the
    # burn chart in the middle, three session cards on the right (the middle one waiting, accent border)
    sw, sh = dr - dl - 2 * bezel, db - dt - 2 * bezel
    screen = Image.new("RGBA", (sw, sh))
    sd = ImageDraw.Draw(screen)
    for i in range(sw):
        t = i / (sw - 1)
        w = 0.45 * (1 - t) ** 1.4 + 0.08
        sd.line([(i, 0), (i, sh)], fill=tuple(int(bg[k] * (1 - w) + accent[k] * w) for k in range(3)) + (255,))
    dim = tuple(int(line[k] * 0.6 + accent[k] * 0.4) for k in range(3)) + (255,)
    soft = tuple(int(card[k] * 0.4 + text[k] * 0.6) for k in range(3)) + (255,)
    pad = 14
    # left: mascot tile (a small hat silhouette) and a clock made of dots
    sd.rounded_rectangle([pad, pad, pad + 96, sh - pad], radius=8, fill=card, outline=line, width=2)
    sd.polygon([(pad + 48, pad + 14), (pad + 30, pad + 52), (pad + 66, pad + 52)], fill=accent)      # hat
    sd.rectangle([pad + 22, pad + 50, pad + 74, pad + 58], fill=accent)                              # brim
    sd.rectangle([pad + 34, pad + 66, pad + 62, pad + 84], fill=soft)                                # face
    for i, wdt in enumerate((44, 30)):                                                               # clock lines
        sd.rectangle([pad + 26, pad + 96 + i * 14, pad + 26 + wdt, pad + 102 + i * 14], fill=dim if i else soft)
    # middle: three limit bars and a burn chart
    mx0 = pad + 112
    for i, fill in enumerate((0.62, 0.33, 0.45)):
        y = pad + 4 + i * 22
        sd.rounded_rectangle([mx0, y, mx0 + 150, y + 12], radius=6, fill=line)
        sd.rounded_rectangle([mx0, y, mx0 + int(150 * fill), y + 12], radius=6, fill=accent)
    bars = (3, 5, 4, 8, 11, 7, 9, 13, 10, 6, 4, 7)
    bx, by = mx0, sh - pad
    for i, h in enumerate(bars):
        sd.rectangle([bx + i * 12, by - h * 3, bx + i * 12 + 8, by], fill=accent if i in (4, 7) else dim)
    # right: session cards
    cx0 = mx0 + 170
    cw = (sw - pad - cx0 - 2 * 10) // 3
    for i in range(3):
        left = cx0 + i * (cw + 10)
        waiting = i == 1
        sd.rounded_rectangle([left, pad, left + cw, sh - pad], radius=8, fill=card, outline=(accent if waiting else line), width=(3 if waiting else 2))
        sd.rectangle([left + 12, pad + 12, left + 12 + 8, pad + 20], fill=(accent if waiting else soft))         # status dot
        sd.rectangle([left + 26, pad + 12, left + cw - 14, pad + 20], fill=soft)                                # title
        sd.rectangle([left + 12, pad + 32, left + cw - 30, pad + 38], fill=dim)
        sd.rectangle([left + 12, pad + 46, left + cw - 18, pad + 52], fill=dim)
        sd.rectangle([left + 12, pad + 60, left + cw - 40, pad + 66], fill=dim)
        sd.rounded_rectangle([left + 12, sh - pad - 30, left + cw - 12, sh - pad - 22], radius=4, fill=line)
        sd.rounded_rectangle([left + 12, sh - pad - 30, left + 12 + int((cw - 24) * (0.7, 0.35, 0.5)[i]), sh - pad - 22], radius=4, fill=accent)
        if waiting:
            sd.rounded_rectangle([left + cw - 50, sh - pad - 30, left + cw - 12, sh - pad - 12], radius=4, fill=accent)   # answer pill
    sm = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(sm).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=12, fill=255)
    art.paste(screen, (dl + bezel, dt + bezel), sm)
    d.line([(dl + bezel + 12, dt + bezel + 1), (dr - bezel - 12, dt + bezel + 1)], fill=text[:3] + (110,), width=2)
    # a stand under the display so it sits on the ground
    d.rectangle([SIZE // 2 - 90, db, SIZE // 2 + 90, db + 22], fill=(0x22, 0x22, 0x2C, 255))
    d.rounded_rectangle([SIZE // 2 - 190, db + 20, SIZE // 2 + 190, db + 42], radius=10, fill=(0x22, 0x22, 0x2C, 255))
    return art, mask


art, mask = compose(0.10)
out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
out.paste(art, (0, 0), mask)
full, _ = compose(0.0)
if OUT_PNG:
    out.save(OUT_PNG)
    print("wrote", OUT_PNG)
else:
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "ChibiDeck.iconset"
        iconset.mkdir()
        for px in (16, 32, 64, 128, 256, 512, 1024):
            im = out.resize((px, px), Image.LANCZOS if px < 256 else Image.BOX)
            if px <= 512:
                im.save(iconset / f"icon_{px}x{px}.png")
            if px >= 32:
                im.save(iconset / f"icon_{px // 2}x{px // 2}@2x.png")
        (ROOT / "Resources").mkdir(exist_ok=True)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(ROOT / "Resources/ChibiDeck.icns")], check=True)
    print("wrote Resources/ChibiDeck.icns")
    # Icon Composer package for macOS 26: one full-bleed image layer, glass/specular/translucency off so the pixel art
    # stays crisp. Scripts/bundle.sh compiles it with actool into Assets.car (CFBundleIconName) when Xcode is present.
    icon_dir = ROOT / "Resources/ChibiDeck.icon"
    (icon_dir / "Assets").mkdir(parents=True, exist_ok=True)
    full.save(icon_dir / "Assets/art.png")
    off = [{"value": False}, {"appearance": "dark", "value": False}]
    (icon_dir / "icon.json").write_text(json.dumps({
        "fill-specializations": [{"value": {"solid": "srgb:%.5f,%.5f,%.5f,1.00000" % tuple(c / 255 for c in bg[:3])}}],
        "groups": [{
            "hidden": False,
            "layers": [{"hidden": False, "image-name": "art.png", "name": "art",
                        "glass-specializations": off,
                        "position": {"scale": 1, "translation-in-points": [0, 0]}}],
            "lighting": "individual",
            "name": "art",
            "shadow-specializations": [{"value": {"kind": "none", "opacity": 0}}],
            "specular-specializations": off,
            "translucency-specializations": [{"value": {"enabled": False, "value": 0}}, {"appearance": "dark", "value": {"enabled": False, "value": 0}}],
        }],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }, indent=2) + "\n")
    print("wrote Resources/ChibiDeck.icon")
