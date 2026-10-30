#!/usr/bin/env python3
"""Genera los assets pixel-art de POCHLAND de forma determinista.

Salidas -> experience/assets/sprites/
  bg.png              fondo 640x360 (cielo, ciudad, torres, cables)
  platform_tile.png   baldosa 16x16 repetible
  platform_cap_l/r    remates de plataforma
  crate.png           16x16 caja rompible
  bug.png             hoja 2 frames 16x16
  packet.png          hoja 4 frames 8x8
  glow.png            radial 64x64 (blanco, se modula)
  dust.png            2x2 blanco
  star.png            3x3 blanco
"""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "experience" / "assets" / "sprites"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 640, 360

# ---------------------------------------------------------------- palette
NAVY = (7, 11, 21, 255)
NIGHT = (10, 17, 30, 255)
DEEP = (15, 24, 47, 255)
BLUE = (27, 39, 55, 255)
SLATE = (56, 74, 85, 255)
STEEL = (77, 83, 69, 255)
MOSS_D = (16, 53, 28, 255)
MOSS = (21, 79, 33, 255)
GREEN = (28, 122, 46, 255)
GREEN_M = (46, 168, 76, 255)
MINT = (88, 226, 122, 255)
CREAM = (244, 233, 216, 255)
PEACH = (198, 136, 100, 255)
BROWN = (89, 29, 3, 255)
CYAN = (102, 224, 208, 255)
CYAN_D = (34, 92, 96, 255)
AMBER = (231, 180, 90, 255)
MAGENTA = (228, 88, 140, 255)
RED = (239, 82, 78, 255)
TRANSPARENT = (0, 0, 0, 0)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def px(draw, x, y, color):
    draw.point((int(x), int(y)), fill=color)


# ---------------------------------------------------------------- font 3x5
GLYPHS = {
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"],
    "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "101", "110", "101", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["101", "111", "111", "111", "101"],
    "O": ["010", "101", "101", "101", "010"],
    "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "111", "011"],
    "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "011"],
    "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"],
    "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "Z": ["111", "001", "010", "100", "111"],
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"],
    "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "110", "001", "110"],
    "6": ["011", "100", "111", "101", "111"],
    "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "110"],
    ">": ["100", "010", "001", "010", "100"],
    "_": ["000", "000", "000", "000", "111"],
    "-": ["000", "000", "111", "000", "000"],
    "/": ["001", "001", "010", "100", "100"],
    " ": ["000", "000", "000", "000", "000"],
}


def draw_text(draw, x, y, text, color, scale=1, spacing=1):
    cursor = x
    for ch in text.upper():
        rows = GLYPHS.get(ch, GLYPHS[" "])
        for ry, row in enumerate(rows):
            for rx, bit in enumerate(row):
                if bit == "1":
                    draw.rectangle(
                        [cursor + rx * scale, y + ry * scale,
                         cursor + rx * scale + scale - 1, y + ry * scale + scale - 1],
                        fill=color,
                    )
        cursor += (3 + spacing) * scale
    return cursor


# ---------------------------------------------------------------- background
def make_background() -> Image.Image:
    rng = random.Random(20261030)
    img = Image.new("RGBA", (W, H), NAVY)
    d = ImageDraw.Draw(img)

    # cielo con bandas y dithering
    top = (5, 8, 17)
    mid = (13, 25, 45)
    horizon = (22, 40, 60)
    for y in range(0, H):
        t = y / (H * 0.82)
        if t < 0.62:
            c = lerp(top, mid, t / 0.62)
        else:
            c = lerp(mid, horizon, (t - 0.62) / 0.38)
        d.line([(0, y), (W, y)], fill=(*c, 255))
    # dither suave entre bandas
    for y in range(0, 290):
        for x in range((y * 7) % 4, W, 4):
            if rng.random() < 0.045:
                d.point((x, y), fill=(255, 255, 255, 8))

    # estrellas
    for _ in range(95):
        x = rng.randrange(0, W)
        y = rng.randrange(6, 250)
        bright = rng.choice([(244, 233, 216, 80), (244, 233, 216, 140),
                             (244, 233, 216, 210), (102, 224, 208, 120)])
        d.point((x, y), fill=bright)
        if rng.random() < 0.18:
            d.point((x - 1, y), fill=(244, 233, 216, 40))
            d.point((x + 1, y), fill=(244, 233, 216, 40))
            d.point((x, y - 1), fill=(244, 233, 216, 40))
            d.point((x, y + 1), fill=(244, 233, 216, 40))

    # luna pixelada con halo
    moon = (500, 120)
    for r, a in [(34, 10), (29, 18), (25, 26)]:
        d.ellipse([moon[0] - r, moon[1] - r, moon[0] + r, moon[1] + r],
                  fill=(244, 233, 216, a))
    d.ellipse([moon[0] - 20, moon[1] - 20, moon[0] + 20, moon[1] + 20],
              fill=(240, 229, 207, 255))
    # cráteres
    for cx, cy, r in [(-8, -6, 4), (7, 4, 3), (-2, 9, 2), (10, -9, 2)]:
        d.ellipse([moon[0] + cx - r, moon[1] + cy - r,
                   moon[0] + cx + r, moon[1] + cy + r],
                  fill=(205, 192, 172, 255))
    # sombra sutil del limbo
    d.arc([moon[0] - 20, moon[1] - 20, moon[0] + 20, moon[1] + 20], 100, 260,
          fill=(198, 184, 164, 70))

    # bruma cálida en el horizonte (opaca)
    for y in range(232, 300):
        t = (y - 232) / 68.0
        col = lerp((21, 38, 55), (28, 51, 64), t * 0.8)
        for x in range(0, W, 4):
            if (x // 4 + y) % 3 != 0:
                d.point((x, y), fill=(*col, 255))

    # nubes pixel art
    for cx, cy, width in [(120, 92, 70), (360, 62, 46), (540, 128, 90)]:
        for i in range(width):
            t = i / width
            yy = cy + int(math.sin(t * math.pi * 2) * 2)
            d.point((cx + i, yy), fill=(36, 58, 80, 120))
        d.line([(cx + 8, cy + 3), (cx + width - 16, cy + 3)], fill=(44, 68, 88, 80))

    # skyline lejano
    x = -10
    while x < W:
        bw = rng.randrange(22, 52)
        bh = rng.randrange(24, 82)
        base = 300
        topy = base - bh
        d.rectangle([x, topy, x + bw, base], fill=(13, 24, 42, 255))
        # borde superior iluminado
        d.line([(x, topy), (x + bw, topy)], fill=(32, 54, 74, 255))
        d.line([(x + 1, topy + 1), (x + bw - 1, topy + 1)], fill=(18, 33, 50, 255))
        # ventanas
        for wy in range(topy + 6, base - 4, 9):
            for wx in range(x + 5, x + bw - 4, 8):
                if rng.random() < 0.26:
                    col = rng.choice([(231, 180, 90, 100), (102, 224, 208, 80),
                                      (244, 233, 216, 55)])
                    d.point((wx, wy), fill=col)
        # antenas
        if rng.random() < 0.4:
            ax = x + bw // 2
            d.line([(ax, topy), (ax, topy - rng.randrange(5, 14))], fill=(20, 33, 48, 255))
            d.point((ax, topy - 12), fill=(239, 82, 78, 180))
        x += bw + rng.randrange(2, 9)

    # edificios medios
    mids = [(0, 235, 86), (74, 205, 62), (150, 244, 72), (205, 220, 90),
            (300, 240, 66), (342, 200, 52), (385, 252, 74), (452, 226, 58),
            (512, 246, 60), (565, 214, 82)]
    for bx, by, bw in mids:
        d.rectangle([bx, by, bx + bw, 310], fill=(14, 26, 44, 255))
        d.line([(bx, by), (bx + bw, by)], fill=(38, 62, 78, 255))
        d.line([(bx + 1, by + 1), (bx + bw - 1, by + 1)], fill=(23, 38, 55, 255))
        # rejillas / luces
        for wy in range(by + 8, 302, 12):
            for wx in range(bx + 6, bx + bw - 4, 12):
                if rng.random() < 0.38:
                    c = rng.choice([(231, 180, 90, 130), (102, 224, 208, 105),
                                    (88, 226, 122, 90)])
                    d.rectangle([wx, wy, wx + 1, wy + 1], fill=c)
        # detalles de techo
        if rng.random() < 0.55:
            d.rectangle([bx + bw // 2 - 5, by - 6, bx + bw // 2 + 5, by], fill=(11, 20, 34, 255))
            d.point((bx + bw // 2, by - 8), fill=(239, 82, 78, 140))

    # torres de telecomunicaciones
    def tower(x, base_y, height, color):
        top = base_y - height
        half = 12
        # patas
        d.line([(x - half, base_y), (x, top)], fill=color, width=1)
        d.line([(x + half, base_y), (x, top)], fill=color, width=1)
        levels = 5
        for i in range(levels):
            y = base_y - int(height * (i / levels))
            span = int(half * (1 - i / levels) + 2)
            d.line([(x - span, y), (x + span, y)], fill=color)
            # celosía
            if i < levels - 1:
                y2 = base_y - int(height * ((i + 1) / levels))
                span2 = int(half * (1 - (i + 1) / levels) + 2)
                d.line([(x - span, y), (x + span2, y2)], fill=color)
                d.line([(x + span, y), (x - span2, y2)], fill=color)
        # antenas
        d.line([(x, top), (x, top - 16)], fill=color)
        d.line([(x - 7, top + 8), (x + 7, top + 8)], fill=color)
        d.point((x, top - 18), fill=RED)
        d.ellipse([x - 2, top - 20, x + 2, top - 16], fill=(239, 82, 78, 45))

    tower(92, 306, 166, (7, 14, 24, 255))
    tower(566, 312, 210, (7, 14, 24, 255))

    # cables colgantes
    def cable(x1, y1, x2, y2, sag, color, width=1):
        pts = []
        for i in range(61):
            t = i / 60
            x = x1 + (x2 - x1) * t
            y = y1 + (y2 - y1) * t + math.sin(t * math.pi) * sag
            pts.append((x, y))
        d.line(pts, fill=color, width=width)

    cable(-20, 26, 210, 52, 42, (6, 11, 19, 255), 1)
    cable(160, 12, 430, 40, 55, (6, 11, 19, 255), 1)
    cable(440, 30, 680, 18, 34, (6, 11, 19, 255), 1)
    cable(300, 0, 350, 66, 24, (6, 11, 19, 255), 1)
    # lámparas colgantes
    for lx, ly in [(210, 74), (430, 88)]:
        d.line([(lx, ly - 22), (lx, ly)], fill=(9, 16, 26, 255))
        d.rectangle([lx - 3, ly, lx + 3, ly + 3], fill=(30, 40, 44, 255))
        d.point((lx, ly + 4), fill=AMBER)
        for r, a in [(5, 28), (3, 45), (2, 70)]:
            d.ellipse([lx - r, ly + 4 - r, lx + r, ly + 4 + r], fill=(231, 180, 90, a))

    # carteles de neón (guiños del CV)
    def sign(x, y, text, color, glow, scale=2):
        w = len(text) * 4 * scale
        d.rectangle([x - 5, y - 5, x + w + 3, y + 7 * scale + 3], fill=(*glow, 18))
        d.rectangle([x - 4, y - 4, x + w + 2, y + 7 * scale + 1], fill=(8, 16, 26, 210))
        draw_text(d, x, y, text, color, scale=scale)
        d.rectangle([x - 4, y - 4, x + w + 2, y + 7 * scale + 1], outline=(*glow, 70))

    sign(142, 214, "ONT", (74, 146, 104, 255), (33, 166, 74))
    sign(382, 226, "SNMP", (72, 126, 136, 255), (102, 224, 208))
    sign(506, 172, "24/7", (148, 116, 70, 255), (231, 180, 90))
    sign(224, 188, "GO", (56, 126, 134, 255), (102, 224, 208))
    sign(288, 264, "200K", (62, 96, 84, 255), (88, 226, 122))

    # racks de servidores y cajas técnicas
    def rack(x, y, w, h):
        d.rectangle([x, y, x + w, y + h], fill=(12, 22, 37, 255))
        d.rectangle([x, y, x + w, y + h], outline=(35, 53, 70, 255))
        for yy in range(y + 4, y + h - 2, 6):
            for xx in range(x + 3, x + w - 2, 4):
                c = (88, 226, 122, 90) if rng.random() < 0.35 else (56, 74, 85, 90)
                d.point((xx, yy), fill=c)
        d.line([(x + 2, y + 1), (x + w - 2, y + 1)], fill=(70, 110, 90, 100))

    rack(28, 286, 26, 30)
    rack(585, 280, 32, 34)

    # conductos de datos en la distancia media
    for px_, py_, pw_ in [(20, 262, 86), (280, 286, 120), (470, 274, 70)]:
        d.rectangle([px_, py_, px_ + pw_, py_ + 3], fill=(17, 32, 48, 255))
        d.line([(px_, py_), (px_ + pw_, py_)], fill=(46, 78, 82, 255))
        for ix in range(px_ + 6, px_ + pw_ - 4, 17):
            d.rectangle([ix, py_ + 1, ix + 3, py_ + 1], fill=(57, 138, 128, 150))
            d.point((ix + 1, py_ + 2), fill=(102, 224, 208, 110))

    # vegetación lejana (siluetas)
    def bush(x, y, s, color):
        for i in range(s):
            bx = x + rng.randrange(-s, s)
            by = y - rng.randrange(0, s)
            r = rng.randrange(2, 5)
            d.ellipse([bx - r, by - r, bx + r, by + r], fill=color)
        d.rectangle([x - s // 2, y - 4, x + s // 2, y + 6], fill=color)

    for bx in [16, 214, 455, 620]:
        bush(bx, 312, 16, (7, 18, 16, 255))

    # cables y tuberías en primer plano del fondo
    for cy in (286, 296):
        cable(0, cy, 640, cy - 8, 6, (6, 11, 19, 255), 1)
    for lx in (154, 268, 412, 548):
        d.line([(lx, 300), (lx, 320)], fill=(9, 15, 25, 255))
        d.rectangle([lx - 2, 300, lx + 2, 304], fill=(38, 54, 56, 255))
        d.point((lx, 306), fill=(102, 224, 208, 90))

    # vignette pintado para dar foco al centro
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-120, -80, W + 120, H + 100], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(80))
    dark = Image.new("RGBA", (W, H), (3, 6, 12, 255))
    img = Image.composite(img, dark, vig.point(lambda v: 255 if v > 8 else 0))
    # segundo paso de oscurecimiento suave en bordes
    edges = Image.new("RGBA", (W, H), (3, 6, 12, 0))
    ed = ImageDraw.Draw(edges)
    for i in range(36):
        a = int((i / 36) ** 2 * 90)
        ed.rectangle([i, i, W - 1 - i, H - 1 - i], outline=(3, 6, 12, a))
    img = Image.alpha_composite(img, edges)
    # asegurar fondo opaco (los glows usan alfa; se mezclan sobre el azul noche)
    img = Image.alpha_composite(Image.new("RGBA", (W, H), (6, 10, 18, 255)), img)
    return img


# ---------------------------------------------------------------- tiles
def make_platform_tile() -> Image.Image:
    rng = random.Random(7)
    t = Image.new("RGBA", (16, 16), TRANSPARENT)
    d = ImageDraw.Draw(t)
    # cuerpo metálico
    d.rectangle([0, 0, 15, 15], fill=(29, 43, 59, 255))
    d.rectangle([0, 0, 15, 2], fill=(23, 68, 35, 255))
    d.rectangle([0, 2, 15, 4], fill=(28, 96, 43, 255))
    d.rectangle([0, 0, 15, 0], fill=(78, 148, 92, 255))
    # borde superior de hierba
    for x in range(16):
        if rng.random() < 0.35:
            d.point((x, 0), fill=GREEN_M)
        if rng.random() < 0.18:
            d.point((x, 1), fill=(58, 142, 78, 255))
    # brillo de borde
    d.line([(0, 3), (15, 3)], fill=(72, 100, 86, 255))
    d.line([(0, 4), (15, 4)], fill=(44, 62, 70, 255))
    d.line([(0, 5), (15, 5)], fill=(36, 52, 65, 255))
    # placas del cuerpo
    for row in range(7, 16, 4):
        d.line([(0, row), (15, row)], fill=(22, 34, 48, 255))
    # remaches / circuito
    for x in (2, 13):
        for y in (8, 12):
            d.point((x, y), fill=(70, 96, 100, 255))
    d.line([(4, 9), (7, 9)], fill=(34, 76, 82, 255))
    d.line([(8, 12), (12, 12)], fill=(34, 76, 82, 255))
    d.point((8, 9), fill=(102, 224, 208, 110))
    # borde inferior
    d.line([(0, 15), (15, 15)], fill=(14, 24, 36, 255))
    return t


def make_caps():
    left = Image.new("RGBA", (16, 16), TRANSPARENT)
    right = Image.new("RGBA", (16, 16), TRANSPARENT)
    tile = make_platform_tile()
    left.alpha_composite(tile)
    right.alpha_composite(tile)
    dl, dr = ImageDraw.Draw(left), ImageDraw.Draw(right)
    # bisel izquierdo
    for i in range(4):
        dl.line([(0, 4 + i), (i, 4 + i)], fill=(0, 0, 0, 0))
        dl.line([(0, 12 - i), (i, 12 - i)], fill=(0, 0, 0, 0))
    dl.line([(4, 6), (4, 15)], fill=(12, 20, 32, 255))
    dl.line([(1, 5), (4, 5)], fill=(70, 96, 88, 255))
    dl.line([(1, 4), (6, 4)], fill=(38, 52, 58, 255))
    dl.line([(1, 6), (1, 10)], fill=(38, 52, 58, 160))
    # bisel derecho
    for i in range(4):
        dr.line([(15, 4 + i), (15 - i, 4 + i)], fill=(0, 0, 0, 0))
        dr.line([(15, 12 - i), (15 - i, 12 - i)], fill=(0, 0, 0, 0))
    dr.line([(11, 6), (11, 15)], fill=(12, 20, 32, 255))
    dr.line([(11, 5), (14, 5)], fill=(70, 96, 88, 255))
    dr.line([(9, 4), (14, 4)], fill=(38, 52, 58, 255))
    dr.line([(14, 6), (14, 10)], fill=(38, 52, 58, 160))
    return left, right


def make_crate() -> Image.Image:
    img = Image.new("RGBA", (18, 18), TRANSPARENT)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 17, 17], fill=(15, 24, 39, 255))
    d.rectangle([1, 1, 16, 16], fill=(61, 55, 38, 255))
    d.rectangle([2, 2, 15, 15], fill=(76, 66, 42, 255))
    # tablones
    for y in (6, 11):
        d.line([(2, y), (15, y)], fill=(48, 41, 28, 255))
    d.line([(2, 2), (15, 2)], fill=(110, 96, 60, 255))
    d.line([(2, 3), (15, 3)], fill=(92, 80, 50, 255))
    # esquinas metálicas
    for (x, y) in [(1, 1), (13, 1), (1, 13), (13, 13)]:
        d.rectangle([x, y, x + 3, y + 3], fill=(55, 64, 62, 255))
        d.point((x + 1, y + 1), fill=(126, 148, 132, 255))
    # etiqueta
    d.rectangle([6, 6, 11, 11], fill=(21, 79, 33, 255))
    d.rectangle([7, 7, 10, 10], fill=(28, 122, 46, 255))
    d.line([(8, 8), (9, 8)], fill=(244, 233, 216, 255))
    d.point((8, 9), fill=(244, 233, 216, 255))
    d.point((8, 10), fill=(244, 233, 216, 255))
    # brillo
    d.line([(2, 2), (2, 15)], fill=(110, 112, 82, 150))
    return img


def make_bug() -> Image.Image:
    sheet = Image.new("RGBA", (32, 16), TRANSPARENT)
    for f in range(2):
        img = Image.new("RGBA", (16, 16), TRANSPARENT)
        d = ImageDraw.Draw(img)
        # sombra / cuerpo
        d.ellipse([3, 5, 13, 13], fill=(52, 18, 36, 255))
        d.ellipse([4, 5, 12, 12], fill=(147, 36, 74, 255))
        d.ellipse([5, 6, 11, 11], fill=(204, 54, 104, 255))
        d.ellipse([6, 7, 9, 10], fill=(239, 82, 78, 180))
        # ojos
        d.rectangle([5, 7, 6, 8], fill=(244, 233, 216, 255))
        d.rectangle([9, 7, 10, 8], fill=(244, 233, 216, 255))
        d.point((5, 7), fill=(102, 224, 208, 255))
        d.point((10, 7), fill=(102, 224, 208, 255))
        # patas animadas
        off = 0 if f == 0 else 1
        for i in range(3):
            y = 9 + i * 2
            d.line([(4 - off, y), (1, y + 2)], fill=(20, 8, 18, 255))
            d.line([(12 + off, y), (15, y + 2)], fill=(20, 8, 18, 255))
        # antenas
        d.line([(7, 5), (5, 2)], fill=(204, 54, 104, 255))
        d.line([(9, 5), (11, 2)], fill=(204, 54, 104, 255))
        d.point((5, 2), fill=(102, 224, 208, 255))
        d.point((11, 2), fill=(102, 224, 208, 255))
        # glitch pixels
        d.point((1, 6), fill=(102, 224, 208, 160))
        d.point((14, 11), fill=(102, 224, 208, 120))
        sheet.paste(img, (f * 16, 0))
    return sheet


def make_packet() -> Image.Image:
    sheet = Image.new("RGBA", (32, 8), TRANSPARENT)
    frames = [
        [(4, 0), (5, 0), (3, 1), (5, 1), (2, 2), (4, 2), (1, 3), (3, 3), (2, 4), (3, 4), (2, 5), (3, 5), (3, 6)],
        [(4, 0), (3, 1), (4, 1), (2, 2), (3, 2), (1, 3), (2, 3), (1, 4), (2, 4), (2, 5), (3, 5), (3, 6), (4, 6)],
        [(3, 0), (4, 0), (2, 1), (4, 1), (1, 2), (3, 2), (1, 3), (2, 3), (1, 4), (2, 4), (2, 5), (3, 5), (3, 6)],
        [(4, 0), (4, 1), (3, 2), (4, 2), (3, 3), (4, 3), (3, 4), (4, 4), (3, 5), (4, 5), (4, 6), (3, 7)],
    ]
    for f, pix in enumerate(frames):
        img = Image.new("RGBA", (8, 8), TRANSPARENT)
        d = ImageDraw.Draw(img)
        for (x, y) in pix:
            d.point((x, y), fill=CYAN)
        # núcleo
        d.point((3, 3), fill=CREAM)
        d.point((4, 3), fill=CREAM)
        d.point((3, 4), fill=CREAM)
        d.point((4, 4), fill=CREAM)
        d.point((4, 2), fill=(188, 255, 245, 255))
        sheet.paste(img, (f * 8, 0))
    return sheet


def make_glow() -> Image.Image:
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = size / 2
    for y in range(size):
        for x in range(size):
            dist = math.hypot(x - cx + 0.5, y - cy + 0.5) / (size / 2)
            a = max(0.0, 1.0 - dist) ** 2.2
            if a > 0:
                img.putpixel((x, y), (255, 255, 255, int(a * 255)))
    return img


def make_dot(size=2, color=(255, 255, 255, 255)) -> Image.Image:
    return Image.new("RGBA", (size, size), color)


def main():
    bg = make_background()
    bg.save(OUT / "bg.png", optimize=True)
    make_platform_tile().save(OUT / "platform_tile.png")
    left, right = make_caps()
    left.save(OUT / "platform_cap_l.png")
    right.save(OUT / "platform_cap_r.png")
    make_crate().save(OUT / "crate.png")
    make_bug().save(OUT / "bug.png")
    make_packet().save(OUT / "packet.png")
    make_glow().save(OUT / "glow.png")
    make_dot(2).save(OUT / "dust.png")
    make_dot(3).save(OUT / "star.png")
    print("assets:", sorted(p.name for p in OUT.glob("*.png")))
    print("bg size:", bg.size)


if __name__ == "__main__":
    main()
