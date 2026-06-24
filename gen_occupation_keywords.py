# 2025년 귀속 기준(단순)경비율.xlsx의 적용기준내용을 토큰화해
# occupation_data.dart의 각 엔트리에 keywords 필드를 추가한다.
# name/경비율은 보존(코드 기준 매칭), keywords만 신규.
import openpyxl, re

XLSX = r"C:\Users\vedja\Downloads\2025년 귀속 기준(단순)경비율.xlsx"
DART = "lib/core/data/occupation_data.dart"

BOILER = '산업활동을 말한다'
SKIP = {'예 시', '예시', '제 외', '제외', '참고', '예시>', '예 시>'}

def clean_tokens(mid, sub, ssub, desc):
    toks = []
    for x in (mid, sub, ssub):
        if x:
            toks.append(str(x).strip())
    if desc:
        d = str(desc)
        # <제외> 이후는 색인 제외(오매칭 방지)
        for marker in ('<제 외>', '<제외>'):
            idx = d.find(marker)
            if idx != -1:
                d = d[:idx]
        for line in re.split(r'[\n·]', d):  # 줄바꿈, 가운뎃점(·)
            t = line.strip()
            t = t.replace('<', '').replace('>', '')   # 섹션 괄호 제거
            t = re.sub(r'^[◦*\-\s]*', '', t)          # 머리기호 제거
            if not t or BOILER in t or len(t) > 24:
                continue
            toks.append(t)
    seen, out = set(), []
    for t in toks:
        t = re.sub(r'\s+', ' ', t).strip(' .,()·ㆍ')
        if t and t not in SKIP and t not in seen:
            seen.add(t)
            out.append(t)
    return ' '.join(out)[:160]

wb = openpyxl.load_workbook(XLSX, read_only=True, data_only=True)
ws = wb['sheet']
kw = {}
for r in ws.iter_rows(min_row=2, values_only=True):
    code = str(r[1]).strip() if r[1] else None
    if code:
        kw[code] = clean_tokens(r[3], r[4], r[5], r[6])

for c in ('552303', '552307', '523361', '011001', '940100'):
    print(c, '->', kw.get(c))
print('총 keyword 개수:', len(kw))

src = open(DART, encoding='utf-8').read()
lines = src.split('\n')
# idempotent: 이미 추가된 keywords 절은 버리고 새로 붙임.
entry_re = re.compile(
    r"^(\s*'(\d{6})': const OccupationInfo\(.*?standardRate: [\d.]+)"
    r"(?:, keywords: '(?:[^'\\]|\\.)*')?\),\s*$")
patched = missing = 0
bs = chr(92)  # backslash
for i, ln in enumerate(lines):
    m = entry_re.match(ln)
    if m:
        code = m.group(2)
        k = kw.get(code, '')
        kesc = k.replace(bs, bs + bs).replace("'", bs + "'")
        lines[i] = m.group(1) + ", keywords: '" + kesc + "'),"
        patched += 1
        if not k:
            missing += 1
print('패치된 엔트리:', patched, '/ 키워드 없음:', missing)
open(DART, 'w', encoding='utf-8').write('\n'.join(lines))
print('저장 완료')
