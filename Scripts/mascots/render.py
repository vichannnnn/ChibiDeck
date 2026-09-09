#!/usr/bin/env python3
"""Review images for the mascots (Pillow; never used at build time)."""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import rig

DARK = (12, 13, 23, 255)
try:
    FONT = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 14)
    FONT_BIG = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 20)
except OSError:
    FONT = FONT_BIG = ImageFont.load_default()


def rgba(hexv: str):
    h = hexv.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def theme_for(mascot_id: str, themes_dir: Path) -> dict:
    for path in sorted(themes_dir.glob("*.json")):
        theme = json.loads(path.read_text(encoding="utf-8"))
        if theme.get("mascot") == mascot_id:
            return theme
    return {"name": "(no theme)", "background": "#0C0D17", "accent": "#B3A6EA"}


def frame_image(sprite: dict, frame: list) -> Image.Image:
    """1:1 RGBA image of one frame."""
    pal = [rgba(h) for h in sprite["palette"]]
    im = Image.new("RGBA", (sprite["cols"], sprite["rows"]), (0, 0, 0, 0))
    px = im.load()
    for r, row in enumerate(frame):
        for c, ch in enumerate(row):
            if ch != ".":
                px[c, r] = pal[sprite["charMap"][ch]]
    return im


def box_fit(im: Image.Image, box: int, bg) -> Image.Image:
    """MascotView-style: fit the frame in a square box, aspect kept, nearest neighbour."""
    w, h = im.size
    s = min(box / w, box / h)
    scaled = im.resize((int(w * s), int(h * s)), Image.NEAREST)
    out = Image.new("RGBA", (box, box), bg)
    out.alpha_composite(scaled, ((box - scaled.width) // 2, (box - scaled.height) // 2))
    return out


def sheet(sprite: dict, out: Path, scale: int = 3) -> None:
    """Every frame by tier at `scale`×."""
    cols, rows = sprite["cols"], sprite["rows"]
    pad, label = 12, 22
    cw, ch = cols * scale + pad, rows * scale + pad + label
    maxf = max(len(sprite["tiers"][t]) for t in rig.TIERS)
    im = Image.new("RGBA", (max(maxf * cw + pad + 120, 700), len(rig.TIERS) * ch + pad + 40), DARK)
    d = ImageDraw.Draw(im)
    d.text((pad, pad), f"{sprite['displayName']} ({sprite['id']}, {cols}x{rows}, {len(sprite['palette'])} colours)",
           fill=(179, 166, 234, 255), font=FONT_BIG)
    y = pad + 34
    for t in rig.TIERS:
        d.text((pad, y), f"{t.upper()} x{len(sprite['tiers'][t])}", fill=(179, 166, 234, 255), font=FONT)
        for i, f in enumerate(sprite["tiers"][t]):
            x = pad + 120 + i * cw
            d.text((x, y), f"{t}[{i}]", fill=(147, 138, 178, 255), font=FONT)
            im.alpha_composite(frame_image(sprite, f).resize((cols * scale, rows * scale), Image.NEAREST), (x, y + label))
        y += ch
    im.save(out)


def gif(sprite: dict, theme: dict, out: Path, box: int = 220) -> None:
    """The built poses side by side at 4 fps, one loop."""
    pad, label = 10, 26
    bg, accent = rgba(theme["background"]), rgba(theme["accent"])
    W, H = len(rig.TIERS) * (box + pad) + pad, box + label + 2 * pad
    frames = []
    for t in range(max(rig.FRAMES.values())):
        im = Image.new("RGBA", (W, H), (24, 24, 28, 255))
        d = ImageDraw.Draw(im)
        for j, p in enumerate(rig.TIERS):
            x = pad + j * (box + pad)
            fr = sprite["tiers"][p][t % len(sprite["tiers"][p])]
            d.rectangle([x, pad, x + box - 1, pad + label + box - 1], fill=bg)
            im.alpha_composite(box_fit(frame_image(sprite, fr), box, bg), (x, pad + label))
            d.text((x + 8, pad + 5), f"{sprite['displayName']} · {p}", fill=accent, font=FONT)
        frames.append(im.convert("RGB").quantize(colors=128))     # quantize RGB: RGBA → P scrambles the palette
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=250, loop=0)


def loop_gif(sprite: dict, theme: dict, out: Path, box: int = 240, transparent: bool = True) -> None:
    """One panel-sized box cycling every built tier in turn at 4 fps (the README header). Transparent by default
    (GIF's 1-bit alpha is enough for a pixel sprite); `transparent=False` fills the box with the theme background."""
    key = (255, 0, 255, 255)                     # stand-in for "clear": no sprite uses magenta
    bg = key if transparent else rgba(theme["background"])
    frames = [box_fit(frame_image(sprite, fr), box, bg) for t in rig.TIERS for fr in sprite["tiers"][t]]
    colours = sorted({c for f in frames for _, c in f.getcolors(4096)} - {key})[:255]
    table = [key] + colours + [colours[-1]] * (255 - len(colours))     # index 0 is the clear key
    pal = Image.new("P", (1, 1))
    pal.putpalette([v for c in table for v in c[:3]])
    quantized = [f.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
    extra = {"transparency": 0, "disposal": 2} if transparent else {}
    quantized[0].save(out, save_all=True, append_images=quantized[1:], duration=250, loop=0, **extra)


def contact(sprites: list, out: Path, box: int = 280) -> None:
    """cruise[0] of each (sprite, theme) at panel size on its theme background, with name and accent swatch."""
    pad, label = 20, 44
    n = max(1, len(sprites))
    im = Image.new("RGBA", (n * (box + pad) + pad, box + label + 2 * pad), (30, 30, 30, 255))
    d = ImageDraw.Draw(im)
    for i, (sprite, theme) in enumerate(sprites):
        x, y = pad + i * (box + pad), pad
        bg = rgba(theme["background"])
        d.rectangle([x, y, x + box - 1, y + label + box - 1], fill=bg)
        im.alpha_composite(box_fit(frame_image(sprite, sprite["tiers"]["cruise"][0]), box, bg), (x, y + label))
        d.text((x + 10, y + 8), sprite["displayName"], fill=rgba(theme["accent"]), font=FONT_BIG)
        d.text((x + 10, y + 28), theme["name"], fill=(200, 200, 200, 255), font=FONT)
        d.rectangle([x + box - 40, y + 10, x + box - 12, y + 34], fill=rgba(theme["accent"]))
    im.save(out)


def roster(sprites: list, out: Path, box: int = 280, label: int = 40, pad: int = 16, cols: int = 3) -> None:
    """The README roster: cruise[0] of every mascot at the panel's 280 px on its theme, three columns, a labelled row each."""
    rows = -(-len(sprites) // cols)
    im = Image.new("RGBA", (cols * (box + pad) + pad, rows * (box + label + pad) + pad), (30, 30, 30, 255))
    d = ImageDraw.Draw(im)
    for i, (sprite, theme) in enumerate(sprites):
        x, y = pad + (i % cols) * (box + pad), pad + (i // cols) * (box + label + pad)
        bg = rgba(theme["background"])
        d.rectangle([x, y, x + box - 1, y + label + box - 1], fill=bg)
        im.alpha_composite(box_fit(frame_image(sprite, sprite["tiers"]["cruise"][0]), box, bg), (x, y + label))
        d.text((x + 10, y + 8), f"{sprite['displayName']}  ·  {theme['name']}", fill=rgba(theme["accent"]), font=FONT_BIG)
    im.save(out)
