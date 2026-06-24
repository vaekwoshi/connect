import json
import math

def calculate_tax(tax_base):
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

def calculate_labor_deduction(gross_income):
    if gross_income <= 5000000:
        return gross_income * 0.7
    elif gross_income <= 15000000:
        return 3500000 + (gross_income - 5000000) * 0.4
    elif gross_income <= 45000000:
        return 7500000 + (gross_income - 15000000) * 0.15
    elif gross_income <= 100000000:
        return 12000000 + (gross_income - 45000000) * 0.05
    else:
        return 14750000 + (gross_income - 100000000) * 0.02

def calculate_labor_tax_credit_limit(gross_income):
    if gross_income <= 33000000:
        return 740000
    elif gross_income <= 70000000:
        val = 740000 - (gross_income - 33000000) * 0.008
        return max(660000.0, val)
    elif gross_income <= 120000000:
        val = 660000 - (gross_income - 70000000) * 0.5
        return max(500000.0, val)
    else:
        val = 500000 - (gross_income - 120000000) * 0.5
        return max(200000.0, val)

def calculate_labor_tax_credit(gross_income, calculated_tax_share):
    limit = calculate_labor_tax_credit_limit(gross_income)
    if calculated_tax_share <= 1300000:
        val = calculated_tax_share * 0.55
        return min(val, limit)
    else:
        val = 715000 + (calculated_tax_share - 1300000) * 0.3
        return min(val, limit)

def simulate_combined_tax(gross_income, accumulated_freelancer_income, input_months, occupation_code, credit_card, decided_tax):
    months = max(1, min(12, input_months))
    freelancer_income = max(0.0, accumulated_freelancer_income)
    
    # 1. 근로소득금액
    labor_deduction = calculate_labor_deduction(gross_income)
    labor_income_amount = gross_income - labor_deduction
    
    # 2. 프리랜서 사업소득금액 (단순경비율 64.1% 적용)
    annual_estimated_freelancer_income = (freelancer_income / months) * 12
    simple_base_rate_pct = 0.641 # 940909 기본율
    
    estimated_freelancer_expense = annual_estimated_freelancer_income * simple_base_rate_pct
    estimated_freelancer_business_income = annual_estimated_freelancer_income - estimated_freelancer_expense
    
    # 3. 종합소득금액
    total_global_income = labor_income_amount + estimated_freelancer_business_income
    
    # 4. 소득공제 (본인 인적공제 150만 + 카드공제)
    personal_deduction = 1500000.0
    
    # 카드 공제 문턱값 (오직 근로 총급여의 25%)
    threshold = gross_income * 0.25
    excess_spend = max(0.0, credit_card - threshold)
    card_deduction = excess_spend * 0.15 # 신용카드만 사용 가정
    card_deduction = min(3000000.0, card_deduction) # 한도 300만
    
    # 과세표준
    tax_base = max(0.0, total_global_income - personal_deduction - card_deduction)
    
    # 5. 산출세액
    estimated_calculated_tax = calculate_tax(tax_base)
    
    # 6. 근로소득세액공제 안분 적용
    labor_calculated_tax_share = 0.0
    if total_global_income > 0:
        labor_calculated_tax_share = estimated_calculated_tax * (labor_income_amount / total_global_income)
    labor_tax_credit = calculate_labor_tax_credit(gross_income, labor_calculated_tax_share)
    
    # 7. 결정세액
    estimated_income_tax = max(0.0, estimated_calculated_tax - labor_tax_credit)
    final_income_tax = truncate_won(estimated_income_tax)
    final_local_tax = truncate_won(final_income_tax * 0.1)
    final_total_tax = final_income_tax + final_local_tax
    
    # 8. 기납부세액
    freelancer_withholding_income = truncate_won(annual_estimated_freelancer_income * 0.03)
    freelancer_withholding_local = truncate_won(annual_estimated_freelancer_income * 0.003)
    annual_estimated_freelancer_withholding_total = freelancer_withholding_income + freelancer_withholding_local
    
    annual_estimated_total_withholding = decided_tax + decided_tax * 0.1 + annual_estimated_freelancer_withholding_total
    
    # 예상 환급/추가납부
    expected_refund_or_payment = annual_estimated_total_withholding - final_total_tax
    
    # 비축 저축액
    monthly_reserve = 0.0
    if expected_refund_or_payment < 0:
        additional_payment = abs(expected_refund_or_payment)
        remaining_months = 12 - months
        if remaining_months > 0:
            monthly_reserve = truncate_won(additional_payment / remaining_months)
        else:
            monthly_reserve = truncate_won(additional_payment)
            
    return {
        'labor_income_amount': labor_income_amount,
        'estimated_freelancer_business_income': estimated_freelancer_business_income,
        'total_global_income': total_global_income,
        'tax_base': tax_base,
        'estimated_calculated_tax': estimated_calculated_tax,
        'labor_tax_credit': labor_tax_credit,
        'final_income_tax': final_income_tax,
        'final_local_tax': final_local_tax,
        'final_total_tax': final_total_tax,
        'annual_estimated_total_withholding': annual_estimated_total_withholding,
        'expected_refund_or_payment': expected_refund_or_payment,
        'monthly_reserve': monthly_reserve
    }

# 시나리오 검증 실행
res = simulate_combined_tax(
    gross_income=40000000.0,
    accumulated_freelancer_income=15000000.0,
    input_months=6,
    occupation_code='940909',
    credit_card=15000000.0,
    decided_tax=1000000.0
)

print("[N잡러 통합 과세 시뮬레이션 검증]")
print(f"근로소득금액: {res['labor_income_amount']} 원 (기대값: 28750000)")
print(f"추정 프리랜서 소득금액: {res['estimated_freelancer_business_income']} 원 (기대값: 10770000)")
print(f"종합소득금액: {res['total_global_income']} 원 (기대값: 39520000)")
print(f"종합소득 과세표준: {res['tax_base']} 원 (기대값: 35770000)") # 카드공제 75만, 인적공제 150만 차감 ➔ 3952만 - 225만 = 3727만 원?
# 아, tax_base = 3952만 - 225만 = 3727만 원.
print(f"산출세액: {res['estimated_calculated_tax']} 원 (기대값: 4330500)")
print(f"근로소득세액공제액: {res['labor_tax_credit']} 원 (기대값: 684000)")
print(f"종합소득세 결정세액 (국세): {res['final_income_tax']} 원 (기대값: 3646500)")
print(f"지방소득세 결정세액 (지방세): {res['final_local_tax']} 원 (기대값: 364650)")
print(f"연간 추정 기납부세액: {res['annual_estimated_total_withholding']} 원 (기대값: 2090000)") # 직장 110만 + 프리랜서 99만 = 209만
print(f"최종 예상 환급/납부액: {res['expected_refund_or_payment']} 원 (기대값: -1921150)")
print(f"월 권장 비축 저축액: {res['monthly_reserve']} 원 (기대값: 320190)")

assert res['labor_income_amount'] == 28750000.0
assert res['estimated_freelancer_business_income'] == 10770000.0
assert res['total_global_income'] == 39520000.0
assert res['tax_base'] == 37270000.0
assert res['estimated_calculated_tax'] == 4330500.0
assert res['labor_tax_credit'] == 684000.0
assert res['final_income_tax'] == 3646500.0
assert res['final_local_tax'] == 364650.0
assert res['annual_estimated_total_withholding'] == 2090000.0
assert res['expected_refund_or_payment'] == -1921150.0
assert res['monthly_reserve'] == 320190.0

print("=> N잡러 통합 연산 검증 스크립트 실행 성공!")
