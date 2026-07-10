"""세끌 아이콘 v2 — Architectural Blueprint 정체성에 맞춘 재제작.
글자는 '세' 한 글자만 (2글자는 소형 아이콘에서 뭉갬), 그 아래 도면 치수선(dimension line)
을 시그니처 요소로 사용 — 측정/계산(세금 계산)이라는 주제와 블루프린트 정체성을 동시에 담는다.
"""
from PIL import Image, ImageDraw, ImageFont

FONT = "C:/Windows/Fonts/NotoSerifKR-VF.ttf"
S = 1024

INK = (0x16, 0x15, 0x13)       # lightInk
GROUND = (0xF8, 0xF7, 0xF5)    # lightBackground (concrete)
ACCENT = (0x1F, 0x5A, 0xE0)    # lightAccent (blueprint blue)


def load_font(size, wght=700):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([wght])
    except Exception as e:
        print("vf set fail", e)
    return f


def build(glyph_size=470, line_w=30, tick_h=78, gap=54, line_pad=0.14):
    """glyph_size: '세' 폰트 크기. line_w: 치수선 굵기. tick_h: 끝 눈금 높이.
    gap: 글자와 치수선 사이 간격. line_pad: 치수선 폭 = 글자폭*(1+line_pad*2)."""
    fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(fg)
    font = load_font(glyph_size)
    text = "세"
    bb = d.textbbox((0, 0), text, font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]

    line_len = int(tw * (1 + line_pad * 2))
    block_h = th + gap + tick_h
    top = (S - block_h) // 2

    tx = (S - tw) // 2 - bb[0]
    ty = top - bb[1]
    d.text((tx, ty), text, font=font, fill=INK)

    ly = top + th + gap + tick_h // 2
    lx0 = (S - line_len) // 2
    lx1 = (S + line_len) // 2
    d.line((lx0, ly, lx1, ly), fill=ACCENT, width=line_w)
    d.line((lx0, ly - tick_h // 2, lx0, ly + tick_h // 2), fill=ACCENT, width=line_w)
    d.line((lx1, ly - tick_h // 2, lx1, ly + tick_h // 2), fill=ACCENT, width=line_w)

    return fg, (tw, th, line_len, block_h)


fg, dims = build(glyph_size=390, line_w=26, tick_h=58, gap=38, line_pad=0.09)
tw, th, line_len, block_h = dims
top = (S - block_h) // 2
ly = top + th + 38 + 58 // 2
tick_top, tick_bot = ly - 58 // 2, ly + 58 // 2
half_w = line_len / 2
import math
corners = [(half_w, tick_top - S / 2), (half_w, tick_bot - S / 2), (-half_w, tick_top - S / 2), (-half_w, tick_bot - S / 2)]
r = max(math.hypot(x, y) for x, y in corners)
print(f"dims={dims}  max_radius={r:.1f}  safe_radius={0.66*S/2:.1f}")
fg.save("design/icon_fg_v2.png")

flat = Image.new("RGB", (S, S), GROUND)
flat.paste(fg, (0, 0), fg)
flat.save("design/icon_v2.png")
print("saved design/icon_fg_v2.png, design/icon_v2.png")
