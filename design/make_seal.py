from PIL import Image, ImageDraw, ImageFont
FONT="C:/Windows/Fonts/NotoSerifKR-VF.ttf"; S=1024
BROWN=(0x6E,0x45,0x28); PAPER=(0xF4,0xEF,0xE6)
def font_at(size,wght=700):
    f=ImageFont.truetype(FONT,size)
    try: f.set_variation_by_axes([wght])
    except Exception: pass
    return f
def make(path, bg, size, xcross, ypad, radius, line):
    img=Image.new("RGBA",(S,S),(0,0,0,0)) if bg is None else Image.new("RGB",(S,S),bg)
    d=ImageDraw.Draw(img); font=font_at(size); text="세끌"
    bb=d.textbbox((0,0),text,font=font); tw,th=bb[2]-bb[0],bb[3]-bb[1]
    cx,cy=S//2,S//2
    tx=cx-tw//2-bb[0]; ty=cy-th//2-bb[1]
    box=(cx-tw//2+xcross, cy-th//2-ypad, cx+tw//2-xcross, cy+th//2+ypad)
    d.rounded_rectangle(box, radius=radius, outline=BROWN, width=line)
    d.text((tx,ty),text,font=font,fill=BROWN)
    img.save(path); print("saved",path)
# 마스터(iOS·레거시): 풀 종이 바탕
make("design/icon_master.png", PAPER, 360, 12, 46, 22, 11)
# 적응형 전경(안드로이드): 투명 + 안전영역에 맞게 축소
make("design/icon_fg.png", None, 300, 10, 40, 18, 10)
