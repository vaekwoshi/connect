from PIL import Image, ImageDraw, ImageFont

FONT = "C:/Windows/Fonts/NotoSerifKR-VF.ttf"
S = 1024

def load_font(size, wght=600):
    f = ImageFont.truetype(FONT, size)
    try: f.set_variation_by_axes([wght])
    except Exception as e: print("vf set fail", e)
    return f

def make(path, ground, frame, ink, accent_is_frame=True):
    img = Image.new("RGB", (S, S), ground)
    d = ImageDraw.Draw(img)
    # 도면 블루 프레임 (둥근 사각, 안전영역 안쪽)
    m = 232                      # 가장자리 여백(안전영역)
    box = (m, m, S-m, S-m)
    d.rounded_rectangle(box, radius=44, outline=frame, width=12)
    # 얇은 안쪽 이중선(도면 명판 디테일)
    d.rounded_rectangle((m+26, m+26, S-m-26, S-m-26), radius=28, outline=frame, width=3)
    # 세끌 — 가로, 중앙
    font = load_font(205)
    text = "세끌"
    bb = d.textbbox((0,0), text, font=font)
    tw, th = bb[2]-bb[0], bb[3]-bb[1]
    tx = (S - tw)//2 - bb[0]
    ty = (S - th)//2 - bb[1]
    d.text((tx, ty), text, font=font, fill=ink)
    # 좌상단 등록 표식(registration tick) — 도면 시그니처
    cx, cy = m+26, m+26
    d.line((cx-2, cy+54, cx-2, cy-2, cx+54, cy-2), fill=frame, width=10) if False else None
    img.save(path)
    print("saved", path)

# 변형 A — 콘크리트(종이)
make("design/icon_paper.png", ground=(0xF8,0xF7,0xF5), frame=(0x1F,0x5A,0xE0), ink=(0x16,0x15,0x13))
# 변형 B — 무광 블랙
make("design/icon_dark.png",  ground=(0x0D,0x0D,0x0D), frame=(0x6A,0x93,0xF0), ink=(0xF8,0xF7,0xF5))
