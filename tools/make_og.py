#!/usr/bin/env python3
"""Genera la portada Open Graph 1200x630 del portafolio."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
W, H = 1200, 630
TEXT = (244, 233, 216, 255)
MUTED = (147, 161, 181, 255)
GREEN = (33, 166, 74, 255)
MINT = (88, 226, 122, 255)
CYAN = (102, 224, 208, 255)

def font(path, size):
    return ImageFont.truetype(str(ROOT / path), size)

sg_bold = font('tools/fonts/SpaceGrotesk-Bold.ttf', 74)
sg_med = font('tools/fonts/SpaceGrotesk-Bold.ttf', 20)
jb = font('experience/fonts/JetBrainsMono-Regular.ttf', 12)
jb_s = font('experience/fonts/JetBrainsMono-Regular.ttf', 10)
jb_b = font('experience/fonts/JetBrainsMono-SemiBold.ttf', 11)
ps = font('experience/fonts/PressStart2P-Regular.ttf', 22)
ps_s = font('experience/fonts/PressStart2P-Regular.ttf', 8)

img = Image.new('RGBA', (W, H), (8, 13, 24, 255))
# glows suaves en capas
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
for r, a in [(600, 8), (420, 12), (260, 16)]:
    gd.ellipse([1010 - r, 40 - r, 1010 + r, 40 + r], fill=(33, 166, 74, a))
for r, a in [(430, 6), (280, 10)]:
    gd.ellipse([170 - r, 560 - r, 170 + r, 560 + r], fill=(102, 224, 208, a))
glow = glow.filter(ImageFilter.GaussianBlur(30))
img = Image.alpha_composite(img, glow)
d = ImageDraw.Draw(img)

for x in range(0, W, 42):
    d.line([(x, 0), (x, H)], fill=(244, 233, 216, 9))
for y in range(0, H, 42):
    d.line([(0, y), (W, y)], fill=(244, 233, 216, 9))

d.rectangle([26, 26, W - 27, H - 27], outline=(244, 233, 216, 26), width=1)
for cx, cy, dx, dy in [(40, 40, 1, 1), (W - 40, 40, -1, 1), (40, H - 40, 1, -1), (W - 40, H - 40, -1, -1)]:
    d.line([(cx, cy), (cx + dx * 26, cy)], fill=MINT, width=2)
    d.line([(cx, cy), (cx, cy + dy * 26)], fill=MINT, width=2)

sheet = Image.open(ROOT / 'raw-assets/poch-sheet.png').convert('RGBA')
sprite = sheet.crop((0, 0, 16, 16))

# marca
d.rectangle([60, 55, 100, 95], fill=(11, 20, 34, 255), outline=GREEN, width=2)
img.alpha_composite(sprite.resize((34, 34), Image.NEAREST), (63, 58))
d = ImageDraw.Draw(img)
d.text((111, 57), 'keiberup', font=sg_med, fill=TEXT)
d.text((112, 83), 'FULLSTACK / TELECOM', font=jb_s, fill=MUTED)

right = 'PORTFOLIO / 2026'
d.text((1122 - d.textlength(right, font=jb_s), 60), right, font=jb_s, fill=MUTED)
d.line([(1074, 80), (1122, 80)], fill=(33, 166, 74, 200), width=2)

d.rectangle([62, 167, 68, 173], fill=MINT)
d.text((80, 161), 'FULLSTACK DEVELOPER  /  CARACAS, VE', font=jb, fill=GREEN)

y = 198
for line, col in [('Sistemas que', TEXT), ('aguantan.', TEXT), ('Interfaces que se', MINT), ('sienten vivas.', MINT)]:
    d.text((60, y), line, font=sg_bold, fill=col)
    y += 78

d.text((62, 538), 'Backend, redes y datos. 7+ años en telecomunicaciones.', font=jb, fill=MUTED)
d.text((62, 584), 'keiberup.dev', font=jb_b, fill=TEXT)
d.text((186, 584), '·', font=jb_b, fill=(147, 161, 181, 120))
d.text((204, 584), 'keiberup.dev@gmail.com', font=jb, fill=MUTED)

# tarjeta de jugador
cx, cy, cw, ch = 760, 158, 374, 350
d.rectangle([cx, cy, cx + cw, cy + ch], fill=(10, 19, 33, 255), outline=(56, 74, 85, 255), width=1)
d.line([(cx, cy + 40), (cx + cw, cy + 40)], fill=(56, 74, 85, 255))
d.text((cx + 18, cy + 13), 'PLAYER CARD // 01', font=jb_s, fill=MUTED)
lv = 'LV. 07'
d.text((cx + cw - 18 - d.textlength(lv, font=jb_s), cy + 13), lv, font=jb_s, fill=MUTED)

sx, sy, sw, sh = cx + 18, cy + 58, cw - 36, 178
d.rectangle([sx, sy, sx + sw, sy + sh], fill=(7, 14, 25, 255))
for gx in range(sx, sx + sw, 28):
    d.line([(gx, sy), (gx, sy + sh)], fill=(88, 226, 122, 14))
for gy in range(sy, sy + sh, 22):
    d.line([(sx, gy), (sx + sw, gy)], fill=(88, 226, 122, 14))

# glow suave detrás del sprite
sglow = Image.new('RGBA', (260, 260), (0, 0, 0, 0))
sgd = ImageDraw.Draw(sglow)
for r, a in [(120, 18), (92, 24), (64, 30), (40, 38)]:
    sgd.ellipse([130 - r, 130 - r, 130 + r, 130 + r], fill=(33, 166, 74, a))
sglow = sglow.filter(ImageFilter.GaussianBlur(22))
img.alpha_composite(sglow, (sx + sw // 2 - 130, sy + 92 - 130))
d = ImageDraw.Draw(img)
img.alpha_composite(sprite.resize((88, 88), Image.NEAREST), (sx + sw // 2 - 44, sy + 92 - 44))
d = ImageDraw.Draw(img)
d.line([(sx + 78, sy + 144), (sx + sw - 78, sy + 144)], fill=(46, 168, 76, 255), width=2)
d.line([(sx + 100, sy + 147), (sx + sw - 100, sy + 147)], fill=(21, 79, 33, 255), width=1)

# decoraciones del juego
bug = sheet.crop((0, 0, 16, 16)).copy()  # bug sheet is separate; use real
bug = Image.open(ROOT / 'experience/assets/sprites/bug.png').crop((0, 0, 16, 16))
img.alpha_composite(bug.resize((26, 26), Image.NEAREST), (sx + 34, sy + 84))
d = ImageDraw.Draw(img)
packet = Image.open(ROOT / 'experience/assets/sprites/packet.png').crop((0, 0, 8, 8))
img.alpha_composite(packet.resize((18, 18), Image.NEAREST), (sx + sw - 52, sy + 54))
d = ImageDraw.Draw(img)

d.text((sx + 10, sy + 9), 'SIGNAL OK', font=ps_s, fill=MINT)
d.text((sx + sw - 84, sy + 9), 'X 048 / Y 028', font=jb_s, fill=(147, 161, 181, 200))

by = 407
d.text((cx + 18, by), 'POCH', font=ps, fill=TEXT)
d.text((cx + 118, by + 8), '// COMPAÑERO DE EQUIPO', font=jb_s, fill=MUTED)
rows = [('ROL', 'FULLSTACK'), ('BASE', 'CARACAS, VE')]
ry = by + 34
for k, v in rows:
    d.text((cx + 18, ry), k, font=jb_s, fill=MUTED)
    d.text((cx + cw - 18 - d.textlength(v, font=jb_s), ry), v, font=jb_s, fill=TEXT)
    d.line([(cx + 18, ry + 14), (cx + cw - 18, ry + 14)], fill=(244, 233, 216, 18))
    ry += 20

d.text((cx + 18, ry + 2), 'SEÑAL', font=jb_s, fill=MUTED)
for i in range(12):
    col = MINT if i < 9 else (30, 50, 58, 255)
    d.rectangle([cx + 18 + i * 21, ry + 20, cx + 18 + i * 21 + 15, ry + 27], fill=col)
d.text((cx + cw - 56, ry + 2), '92%', font=jb_s, fill=MINT)
d.text((cx + cw - 18 - d.textlength('GODOT 4.7 / WEB', font=jb_s), cy + ch + 12),
       'GODOT 4.7 / WEB', font=jb_s, fill=(147, 161, 181, 150))

d.text((1122 - d.textlength('POCHLAND // WEB', font=jb_s), H - 58),
       'POCHLAND // WEB', font=jb_s, fill=(147, 161, 181, 130))

out = ROOT / 'site/assets/img/og-cover.png'
img.convert('RGB').save(out, optimize=True)
print('OG', out, out.stat().st_size)
