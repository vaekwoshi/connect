"""PDF 텍스트 추출 (pypdf). 페이지별 마커 포함."""
import sys
from pypdf import PdfReader

def main(path, out_path, start=None, end=None):
    reader = PdfReader(path)
    n = len(reader.pages)
    s = (start - 1) if start else 0
    e = end if end else n
    chunks = []
    for i in range(s, e):
        txt = reader.pages[i].extract_text() or ''
        chunks.append(f"\n===== PAGE {i+1} =====\n{txt}")
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(chunks))
    print(f"pages {s+1}-{e} of {n} -> {out_path}")

if __name__ == '__main__':
    path = sys.argv[1]
    out_path = sys.argv[2]
    start = int(sys.argv[3]) if len(sys.argv) > 3 else None
    end = int(sys.argv[4]) if len(sys.argv) > 4 else None
    main(path, out_path, start, end)
