"""HWP 5.0 본문 텍스트 추출기.
HWP는 OLE 복합문서. BodyText/Section* 스트림이 raw-deflate 압축돼 있음.
각 레코드 헤더(4바이트): tag_id(10bit) | level(10bit) | size(12bit).
tag_id 67 (HWPTAG_PARA_TEXT) 안의 UTF-16LE 텍스트만 뽑되,
제어문자(0~31)는 인라인 컨트롤이라 적절히 스킵/치환.
"""
import sys, zlib, struct
import olefile

HWPTAG_BEGIN = 0x10
HWPTAG_PARA_TEXT = HWPTAG_BEGIN + 51  # 67

# 인라인 컨트롤 char 코드: 일부는 8바이트(=char 16바이트) 확장 컨트롤
EXT_CTRL = {1,2,3,4,5,6,7,8,9,11,12,14,15,16,17,18,21,22,23}
INLINE_CTRL = {0,10,13,24,25,26,27,28,29,30,31}  # 일부는 단독

def parse_records(data):
    i = 0
    n = len(data)
    while i + 4 <= n:
        header = struct.unpack('<I', data[i:i+4])[0]
        tag_id = header & 0x3FF
        level = (header >> 10) & 0x3FF
        size = (header >> 20) & 0xFFF
        i += 4
        if size == 0xFFF:
            size = struct.unpack('<I', data[i:i+4])[0]
            i += 4
        payload = data[i:i+size]
        i += size
        yield tag_id, level, payload

def extract_para_text(payload):
    out = []
    j = 0
    n = len(payload)
    while j + 2 <= n:
        code = struct.unpack('<H', payload[j:j+2])[0]
        if code in EXT_CTRL:
            j += 16  # 확장 컨트롤은 8 WCHAR(16바이트)
            out.append(' ')
            continue
        if code in INLINE_CTRL:
            j += 2
            if code in (10, 13):
                out.append('\n')
            else:
                out.append(' ')
            continue
        # 일반 문자
        out.append(chr(code))
        j += 2
    return ''.join(out)

def main(path):
    ole = olefile.OleFileIO(path)
    streams = ole.listdir()
    sections = sorted([s for s in streams if len(s) == 2 and s[0] == 'BodyText'],
                      key=lambda s: s[1])
    texts = []
    for sec in sections:
        raw = ole.openstream(sec).read()
        try:
            data = zlib.decompress(raw, -15)
        except zlib.error:
            data = raw  # 비압축 문서
        for tag_id, level, payload in parse_records(data):
            if tag_id == HWPTAG_PARA_TEXT:
                t = extract_para_text(payload)
                if t.strip():
                    texts.append(t)
    ole.close()
    result = '\n'.join(texts)
    if len(sys.argv) > 2:
        with open(sys.argv[2], 'w', encoding='utf-8') as f:
            f.write(result)
    else:
        sys.stdout.buffer.write(result.encode('utf-8'))

if __name__ == '__main__':
    main(sys.argv[1])
