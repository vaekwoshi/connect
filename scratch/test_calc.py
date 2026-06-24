import json
import math

def calculate_tax(tax_base):
    # 종합소득세 세율 구간 (2024~2025 귀속)
    brackets = [
        (14000000, 0.06, 0),
        (50000000, 0.15, 1260000),
        (88000000, 0.24, 5760000),
        (150000000, 0.35, 15440000),
        (300000000, 0.38, 19940000),
        (500000000, 0.40, 25940000),
        (1000000000, 0.42, 35940000),
        (float('inf'), 0.45, 65940000)
    ]
    if tax_base <= 0:
        return 0
    for limit, rate, deduction in brackets:
        if tax_base <= limit:
            return (tax_base * rate) - deduction
    return 0

def truncate_won(amount):
    return math.floor(amount / 10) * 10

def calculate_tax_simulation(accumulated_income, input_months, allowance_count, occupation_code):
    months = max(1, min(12, input_months))
    income = max(0.0, accumulated_income)
    dependents = max(0, allowance_count)
    
    # 2025년 귀속 경비율.json 로드
    with open('지식_변환/JSON/2025년 귀속 경비율.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    rows = data.get('데이터', [])
    simple_base_rate = 0.0
    simple_excess_rate = 0.0
    standard_rate = 0.0
    occupation_name = '미등록 업종'
    
    for row in rows[2:]:
        if row[0].strip() == occupation_code:
            occupation_name = row[1].strip()
            simple_base_rate = float(row[2].strip()) if row[2] else 0.0
            simple_excess_rate = float(row[3].strip()) if len(row) > 3 and row[3] else 0.0
            if simple_excess_rate == 0.0:
                simple_excess_rate = simple_base_rate
            standard_rate = float(row[4].strip()) if len(row) > 4 and row[4] else 0.0
            break
            
    simple_base_rate_pct = simple_base_rate / 100.0
    simple_excess_rate_pct = simple_excess_rate / 100.0
    
    # 미래 예측 (연환산 연소득)
    annual_estimated_income = (income / months) * 12
    
    # 필요경비 (단순경비율)
    if annual_estimated_income <= 40000000:
        estimated_expense = annual_estimated_income * simple_base_rate_pct
    else:
        estimated_expense = (40000000 * simple_base_rate_pct) + ((annual_estimated_income - 40000000) * simple_excess_rate_pct)
        
    estimated_business_income = annual_estimated_income - estimated_expense
    
    # 인적공제
    deduction = (dependents + 1) * 1500000.0
    
    # 과세표준
    tax_base = estimated_business_income - deduction
    if tax_base < 0:
        tax_base = 0
        
    # 산출세액
    estimated_calculated_tax = calculate_tax(tax_base)
    estimated_local_tax = estimated_calculated_tax * 0.1
    
    final_annual_income_tax = truncate_won(estimated_calculated_tax)
    final_annual_local_tax = truncate_won(estimated_local_tax)
    final_annual_total_tax = final_annual_income_tax + final_annual_local_tax
    
    # 기납부세액
    paid_income_tax = truncate_won(income * 0.03)
    paid_local_tax = truncate_won(income * 0.003)
    paid_total_withholding = paid_income_tax + paid_local_tax
    
    annual_estimated_withholding_income = truncate_won(annual_estimated_income * 0.03)
    annual_estimated_withholding_local = truncate_won(annual_estimated_income * 0.003)
    annual_estimated_total_withholding = annual_estimated_withholding_income + annual_estimated_withholding_local
    
    # 예상 결과
    expected_refund_or_payment = annual_estimated_total_withholding - final_annual_total_tax
    
    # 저축 넛지
    monthly_reserve = 0.0
    if expected_refund_or_payment < 0:
        additional_payment = abs(expected_refund_or_payment)
        remaining_months = 12 - months
        if remaining_months > 0:
            monthly_reserve = truncate_won(additional_payment / remaining_months)
        else:
            monthly_reserve = truncate_won(additional_payment)
            
    return {
        'annual_estimated_income': annual_estimated_income,
        'estimated_expense': estimated_expense,
        'estimated_business_income': estimated_business_income,
        'tax_base': tax_base,
        'annual_income_tax': final_annual_income_tax,
        'annual_local_tax': final_annual_local_tax,
        'annual_total_tax': final_annual_total_tax,
        'paid_total_withholding': paid_total_withholding,
        'annual_estimated_total_withholding': annual_estimated_total_withholding,
        'expected_refund_or_payment': expected_refund_or_payment,
        'monthly_reserve': monthly_reserve,
        'occupation_name': occupation_name,
        'simple_base_rate': simple_base_rate,
        'simple_excess_rate': simple_excess_rate,
        'standard_rate': standard_rate
    }

# 시나리오 1 테스트
res1 = calculate_tax_simulation(30000000, 6, 0, '940909')
print("[시나리오 1 - 파이썬 검증]")
print(f"업종명: {res1['occupation_name']}")
print(f"연환산 수입: {res1['annual_estimated_income']}")
print(f"추정 필요경비: {res1['estimated_expense']}")
print(f"추정 사업소득금액: {res1['estimated_business_income']}")
print(f"추정 과세표준: {res1['tax_base']}")
print(f"추정 종합소득세: {res1['annual_income_tax']}")
print(f"추정 지방소득세: {res1['annual_local_tax']}")
print(f"연 추정 기납부 3.3% 세액: {res1['annual_estimated_total_withholding']}")
print(f"최종 예상 환급/납부액: {res1['expected_refund_or_payment']}")
print(f"월 권장 저축액: {res1['monthly_reserve']}")

assert res1['annual_estimated_income'] == 60000000.0
assert res1['estimated_expense'] == 35580000.0
assert res1['estimated_business_income'] == 24420000.0
assert res1['tax_base'] == 22920000.0
assert res1['annual_income_tax'] == 2178000.0
assert res1['annual_local_tax'] == 217800.0
assert res1['expected_refund_or_payment'] == -415800.0
assert res1['monthly_reserve'] == 69300.0
print("시나리오 1 파이썬 검증 통과!")

# 시나리오 2 테스트
res2 = calculate_tax_simulation(10000000, 3, 1, '940918')
print("\n[시나리오 2 - 파이썬 검증]")
print(f"업종명: {res2['occupation_name']}")
print(f"연환산 수입: {res2['annual_estimated_income']}")
print(f"추정 필요경비: {res2['estimated_expense']}")
print(f"추정 사업소득금액: {res2['estimated_business_income']}")
print(f"추정 과세표준: {res2['tax_base']}")
print(f"추정 종합소득세: {res2['annual_income_tax']}")
print(f"추정 지방소득세: {res2['annual_local_tax']}")
print(f"최종 예상 환급/납부액: {res2['expected_refund_or_payment']}")

assert res2['annual_estimated_income'] == 40000000.0
assert res2['estimated_expense'] == 31760000.0
assert res2['estimated_business_income'] == 8240000.0
assert res2['tax_base'] == 5240000.0
assert res2['annual_income_tax'] == 314400.0
assert res2['annual_local_tax'] == 31440.0
assert res2['expected_refund_or_payment'] == 974160.0
print("시나리오 2 파이썬 검증 통과!")

print("\n=== 모든 검증 완료: 100% 성공! ===")
