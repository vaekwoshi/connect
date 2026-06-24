import os
import json

base_dir = r"c:\Users\vedja\.gemini\antigravity\scratch\세끌\지식_변환"
json_dir = os.path.join(base_dir, "JSON")
md_dir = os.path.join(base_dir, "마크다운")

# 1. 직장인
employee_json = {
    "직군": "직장인",
    "대상세금": "연말정산 (근로소득세)",
    "필수입력항목": [
        {"항목명": "세전 연봉(총급여)", "설명": "연간 근로소득 총액"},
        {"항목명": "부양가족 수", "설명": "본인 제외 인적공제 대상 인원"},
        {"항목명": "신용카드 등 사용액", "설명": "신용카드, 체크카드, 전통시장, 대중교통, 도서공연 지출액"},
        {"항목명": "월세 지출액", "설명": "매월 납부하는 월세액 (무주택자)"}
    ],
    "핵심로직": [
        "근로소득공제 적용",
        "신용카드 총급여 25% 문턱 계산 및 우선순위 분배",
        "월세 세액공제 (총급여 5500만원 기준 17% 또는 15%)"
    ]
}
employee_md = """# 직장인 연말정산 계산기 지식베이스
직장인(근로소득자)은 5월 종합소득세 대상이 아니며, 1월 연말정산이 핵심입니다.
- **핵심 파라미터**: 총급여(연봉), 카드사용액, 월세
- **제외 항목**: 사업소득, 경비율, 기장여부 (완전 배제)
"""

# 2. 프리랜서
freelancer_json = {
    "직군": "프리랜서",
    "대상세금": "종합소득세 (5월)",
    "필수입력항목": [
        {"항목명": "사업소득(세전)", "설명": "3.3% 떼기 전 연간 총 수입"},
        {"항목명": "업종코드", "설명": "국세청 업종코드 (예: 940909)"},
        {"항목명": "부양가족 수", "설명": "본인 제외 인적공제 대상 인원"},
        {"항목명": "노란우산공제", "설명": "연간 납입액"}
    ],
    "핵심로직": [
        "단순경비율 또는 기준경비율 적용하여 사업소득금액 도출",
        "인적공제 및 노란우산공제 차감 후 과세표준 산출",
        "6~45% 누진세율 적용 및 3.3% 기납부세액 기정산 후 환급/추징액 도출"
    ]
}
freelancer_md = """# 프리랜서 종합소득세 계산기 지식베이스
전업 프리랜서는 사업소득(3.3%)만 존재하며 5월 종합소득세 신고 대상입니다.
- **핵심 파라미터**: 세전 사업소득, 업종코드(경비율)
- **제외 항목**: 신용카드 소득공제 (프리랜서는 적용 불가)
"""

# 3. N잡러
combined_json = {
    "직군": "N잡러",
    "대상세금": "종합소득세 (근로소득 + 사업소득 합산)",
    "필수입력항목": [
        {"항목명": "세전 연봉(총급여)", "설명": "직장 근로소득"},
        {"항목명": "부업 사업소득(세전)", "설명": "부업으로 번 프리랜서 총 수입"},
        {"항목명": "업종코드", "설명": "부업 업종코드"},
        {"항목명": "신용카드 등 사용액", "설명": "직장 연봉의 25% 문턱 계산용"},
        {"항목명": "1월 결정세액", "설명": "연말정산 시 확정된 기납부 세액"}
    ],
    "핵심로직": [
        "직장 근로소득금액 + 부업 사업소득금액 종합과세표준 합산",
        "신용카드 공제는 '근로소득(총급여)' 기준으로만 한도 적용",
        "직장 1월 결정세액과 부업 3.3% 기납부세액을 모두 공제하여 5월 최종 정산"
    ]
}
combined_md = """# N잡러 합산 종합소득세 계산기 지식베이스
N잡러는 직장 연말정산을 1월에 마치고, 5월에 부업 소득을 합산하여 종합소득세 신고를 다시 해야 합니다.
- **핵심 파라미터**: 근로소득, 사업소득, 신용카드(근로소득 한정)
- **주의사항**: 두 소득이 합산되어 과세표준 구간이 상승(누진세율 폭탄)할 가능성이 높습니다.
"""

# 파일 쓰기
with open(os.path.join(json_dir, '직장인_연말정산_계산기.json'), 'w', encoding='utf-8') as f:
    json.dump(employee_json, f, ensure_ascii=False, indent=2)
with open(os.path.join(md_dir, '직장인_연말정산_계산기.md'), 'w', encoding='utf-8') as f:
    f.write(employee_md)

with open(os.path.join(json_dir, '프리랜서_종소세_계산기.json'), 'w', encoding='utf-8') as f:
    json.dump(freelancer_json, f, ensure_ascii=False, indent=2)
with open(os.path.join(md_dir, '프리랜서_종소세_계산기.md'), 'w', encoding='utf-8') as f:
    f.write(freelancer_md)

with open(os.path.join(json_dir, 'N잡러_합산소득세_계산기.json'), 'w', encoding='utf-8') as f:
    json.dump(combined_json, f, ensure_ascii=False, indent=2)
with open(os.path.join(md_dir, 'N잡러_합산소득세_계산기.md'), 'w', encoding='utf-8') as f:
    f.write(combined_md)

# 기존 뭉쳐진 파일 삭제
old_json = os.path.join(json_dir, '종합소득세 계산기.json')
old_md = os.path.join(md_dir, '종합소득세 계산기.md')
if os.path.exists(old_json): os.remove(old_json)
if os.path.exists(old_md): os.remove(old_md)

print("Split Success")
