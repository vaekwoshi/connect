# 세끌 앱 아이콘 생성 — 블루프린트 톤(크림 배경 + 잉크 세리프 워드마크).
# 전체 아이콘(icon.png) + 안드로이드 적응형 전경(icon_fg.png).
import os
from PIL import Image, ImageDraw, ImageFont

OUT = "assets/icon"
os.makedirs(OUT, exist_ok=True)

CREAM = (248, 247, 245)
INK = (22, 21, 19)
ACCENT = (31, 90, 224)  # 블루프린트 블루
SERIF = "C:/Windows/Fonts/batang.ttc"

def wordmark(draw, cx, cy, size, color):
    font = ImageFont.truetype(SERIF, size, index=0)
    text = "세끌"
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text((cx - w / 2 - box[0], cy - h / 2 - box[1]), text, font=font, fill=color)

# ── 전체 아이콘 (iOS·레거시 안드로이드) ──
S = 1024
img = Image.new("RGB", (S, S), CREAM)
d = ImageDraw.Draw(img)
# 하단 액센트 바 (블루프린트 모티프)
d.rectangle([S * 0.36, S * 0.70, S * 0.64, S * 0.70 + 10], fill=ACCENT)
wordmark(d, S / 2, S / 2 - 20, 430, INK)
img.save(f"{OUT}/icon.png")

# ── 적응형 전경 (투명, 안전영역 안쪽으로 여백 크게) ──
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
df = ImageDraw.Draw(fg)
df.rectangle([S * 0.38, S * 0.64, S * 0.62, S * 0.64 + 9], fill=ACCENT + (255,))
wordmark(df, S / 2, S / 2 - 16, 340, INK)
fg.save(f"{OUT}/icon_fg.png")

print("생성:", os.listdir(OUT))
