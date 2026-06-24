import os
import json

base_dir = r"c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환"
json_dir = os.path.join(base_dir, "JSON")
md_dir = os.path.join(base_dir, "마크다운")

# 기존 파일명
old_json = os.path.join(json_dir, '직장인_연말정산_계산기.json')
old_md = os.path.join(md_dir, '직장인_연말정산_계산기.md')

# 새 파일명
new_json = os.path.join(json_dir, '직장인_5월_종합소득세_계산기.json')
new_md = os.path.join(md_dir, '직장인_5월_종합소득세_계산기.md')

# 1. 수정된 직장인 JSON 데이터
employee_json_updated = {
    "직군": "직장인",
    "대상세금": "5월 종합소득세 확정신고 및 경정청구 (민감정보 누락분 반영)",
    "필수입력항목": [
        {"항목명": "세전 연봉(총급여)", "설명": "연간 근로소득 총액"},
        {"항목명": "1월 연말정산 결정세액", "설명": "1월에 이미 확정된 최종 세액 (이 한도 내에서만 추가 환급 가능)"},
        {"항목명": "부양가족 수", "설명": "본인 제외 인적공제 대상 인원"},
        {"항목명": "신용카드 등 사용액", "설명": "신용카드, 체크카드, 전통시장, 대중교통, 도서공연 지출액"},
        {"항목명": "월세 지출액", "설명": "회사에 알리기 꺼려 누락했던 매월 월세 납부액 (무주택자)"}
    ],
    "핵심로직": [
        "근로소득공제 적용",
        "신용카드 총급여 25% 문턱 계산 및 우선순위 분배",
        "월세 세액공제 (총급여 5500만원 기준 17% 또는 15%) 적용",
        "[결정세액 0원 법칙] 산출된 환급액이 '1월 연말정산 결정세액'을 초과할 경우, 1월 결정세액까지만 100% 전액 환급으로 컷팅(제한)함"
    ]
}

# 2. 수정된 마크다운 데이터
employee_md_updated = """# 직장인 5월 종합소득세(경정청구) 계산기 지식베이스

회사 인사팀에 월세, 난임 시술, 특정 기부금 등 **개인적이고 민감한 정보**를 알리기 꺼려하는 직장인들을 위한 5월 환급 시뮬레이터입니다.
1월 연말정산 때는 국세청 간소화 자료만 제출하여 대충 정산한 뒤, 5월 종합소득세 정기신고 기간에 본인이 직접 홈택스에 민감정보(월세 등)를 추가 입력하여 환급받는 실무에 100% 최적화되어 있습니다.

- **핵심 파라미터**: 총급여(연봉), 1월 결정세액(기납부세액 한도), 누락했던 월세액, 카드사용액
- **주의사항 (결정세액 0원 법칙)**: 아무리 공제를 많이 받아도, 1월에 확정되어 냈던 세금(결정세액)보다 더 많이 돌려받을 수는 없습니다.
- **제외 항목**: 사업소득, 단순/기준경비율, 기장여부 등 프리랜서 전용 항목 (완전 배제)
"""

# 새 파일 쓰기
with open(new_json, 'w', encoding='utf-8') as f:
    json.dump(employee_json_updated, f, ensure_ascii=False, indent=2)
with open(new_md, 'w', encoding='utf-8') as f:
    f.write(employee_md_updated)

# 기존 파일 삭제 (리네임 대체)
if os.path.exists(old_json):
    os.remove(old_json)
if os.path.exists(old_md):
    os.remove(old_md)

print("Update Success")
