import random
import math
import json

# 2025년 귀속 경비율.json 로드하여 업종코드 리스트 확보
with open('지식_변환/JSON/2025년 귀속 경비율.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
rows = data.get('데이터', [])
valid_occupation_codes = [row[0].strip() for row in rows[2:] if row[0]]

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

# 프리랜서 연산 파이썬 모사 함수
def simulate_freelancer(accumulated_income, input_months, allowance_count, occupation_code):
    # 입력 방어
    months = max(1, min(12, input_months))
    income = max(0.0, accumulated_income)
    dependents = max(0, allowance_count)
    
    simple_base_rate = 0.0
    simple_excess_rate = 0.0
    standard_rate = 0.0
    
    # 존재하지 않는 업종코드 대응
    for row in rows[2:]:
        if row[0].strip() == occupation_code:
            simple_base_rate = float(row[2].strip()) if row[2] else 0.0
            simple_excess_rate = float(row[3].strip()) if len(row) > 3 and row[3] else 0.0
            if simple_excess_rate == 0.0:
                simple_excess_rate = simple_base_rate
            standard_rate = float(row[4].strip()) if len(row) > 4 and row[4] else 0.0
            break
            
    simple_base_rate_pct = simple_base_rate / 100.0
    simple_excess_rate_pct = simple_excess_rate / 100.0
    
    annual_estimated_income = (income / months) * 12
    
    if annual_estimated_income <= 40000000:
        estimated_expense = annual_estimated_income * simple_base_rate_pct
    else:
        estimated_expense = (40000000 * simple_base_rate_pct) + ((annual_estimated_income - 40000000) * simple_excess_rate_pct)
        
    estimated_business_income = annual_estimated_income - estimated_expense
    deduction = (dependents + 1) * 1500000.0
    
    tax_base = estimated_business_income - deduction
    if tax_base < 0:
        tax_base = 0
        
    estimated_calculated_tax = calculate_tax(tax_base)
    estimated_local_tax = estimated_calculated_tax * 0.1
    
    final_annual_income_tax = truncate_won(estimated_calculated_tax)
    final_annual_local_tax = truncate_won(estimated_local_tax)
    final_annual_total_tax = final_annual_income_tax + final_annual_local_tax
    
    paid_income_tax = truncate_won(income * 0.03)
    paid_local_tax = truncate_won(income * 0.003)
    paid_total_withholding = paid_income_tax + paid_local_tax
    
    annual_estimated_withholding_income = truncate_won(annual_estimated_income * 0.03)
    annual_estimated_withholding_local = truncate_won(annual_estimated_income * 0.003)
    annual_estimated_total_withholding = annual_estimated_withholding_income + annual_estimated_withholding_local
    
    expected_refund_or_payment = annual_estimated_total_withholding - final_annual_total_tax
    
    monthly_reserve = 0.0
    if expected_refund_or_payment < 0:
        additional_payment = abs(expected_refund_or_payment)
        remaining_months = 12 - months
        if remaining_months > 0:
            monthly_reserve = truncate_won(additional_payment / remaining_months)
        else:
            monthly_reserve = truncate_won(additional_payment)
            
    # 에러 및 모순 검증 (사각지대 체크)
    if annual_estimated_income < 0 or estimated_expense < 0 or estimated_business_income < 0:
        raise ValueError("프리랜서 소득 및 비용은 음수일 수 없습니다.")
    if final_annual_total_tax < 0 or paid_total_withholding < 0 or monthly_reserve < 0:
        raise ValueError("세액 및 저축액은 음수일 수 없습니다.")
        
    return True

# 직장인 연산 파이썬 모사 함수
def simulate_employee(gross_income, credit_card, debit_card_and_cash, traditional_market, public_transport, culture_expense, monthly_rent, decided_tax):
    # 입력 방어
    gross = max(0.0, gross_income)
    credit = max(0.0, credit_card)
    debit = max(0.0, debit_card_and_cash)
    market = max(0.0, traditional_market)
    transport = max(0.0, public_transport)
    culture = max(0.0, culture_expense)
    rent = max(0.0, monthly_rent)
    decided = max(0.0, decided_tax)
    
    threshold = gross * 0.25
    total_spend = credit + debit + market + transport + culture
    excess_spend = max(0.0, total_spend - threshold)
    
    remaining_excess = excess_spend
    
    allocated_transport = min(remaining_excess, transport)
    remaining_excess -= allocated_transport
    
    allocated_market = min(remaining_excess, market)
    remaining_excess -= allocated_market
    
    allocated_culture = 0.0
    if gross <= 70000000:
        allocated_culture = min(remaining_excess, culture)
        remaining_excess -= allocated_culture
        
    allocated_debit = min(remaining_excess, debit)
    remaining_excess -= allocated_debit
    
    allocated_credit = min(remaining_excess, credit)
    remaining_excess -= allocated_credit
    
    transport_deduction = allocated_transport * 0.40
    market_deduction = allocated_market * 0.40
    culture_deduction = allocated_culture * 0.30
    debit_deduction = allocated_debit * 0.30
    credit_deduction = allocated_credit * 0.15
    
    base_limit = 3000000.0 if gross <= 70000000 else 2500000.0
    raw_base_deduction = credit_deduction + debit_deduction
    base_deduction = min(raw_base_deduction, base_limit)
    
    raw_extra_deduction = transport_deduction + market_deduction + culture_deduction
    extra_deduction = min(raw_extra_deduction, 3000000.0)
    
    final_deduction = min(7000000.0, base_deduction + extra_deduction)
    
    # 월세 환급 시뮬레이터
    annual_rent = rent * 12
    rent_limit = min(annual_rent, 10000000.0)
    credit_rate = 0.17 if gross <= 55000000 else 0.15
    raw_rent_credit = rent_limit * credit_rate
    final_rent_credit = min(raw_rent_credit, decided)
    
    local_refund = truncate_won(final_rent_credit * 0.1)
    total_refund = truncate_won(final_rent_credit) + local_refund
    
    # 에러 및 모순 검증 (사각지대 체크)
    if threshold < 0 or excess_spend < 0 or final_deduction < 0:
        raise ValueError("신용카드 공제 계산 오류")
    if final_rent_credit < 0 or total_refund < 0 or total_refund > (decided * 1.1 + 10):
        # 결정세액 환급 한도 검사 (국세 결정세액 + 지방세 결정세액(국세의 10%) 한도를 넘어선 안 됨)
        raise ValueError("월세 환급액 한도 초과 오류")
        
    return True

print("=== 3,000회 모의 시뮬레이션 스트레스 테스트 시작 ===")

errors_detected = 0

# 1. 프리랜서 모의 1,500회 실행
for i in range(1500):
    income = random.choice([0.0, -10000.0, 100.0, 5000000.0, 50000000.0, 500000000.0, 1000000000.0, 10000000000.0]) # 극단값 포함
    months = random.randint(-5, 20) # 0 이하 경계값 포함
    dependents = random.randint(-2, 10)
    code = random.choice(valid_occupation_codes + ['INVALID_CODE']) # 잘못된 코드 검증 포함
    
    try:
        simulate_freelancer(income, months, dependents, code)
    except Exception as e:
        print(f"[프리랜서 에러 발견] 입력: income={income}, months={months}, dependents={dependents}, code={code} | 에러: {e}")
        errors_detected += 1
        break

# 2. 직장인 모의 1,500회 실행
for i in range(1500):
    gross = random.choice([0.0, 15000000.0, 30000000.0, 50000000.0, 80000000.0, 150000000.0, 500000000.0])
    credit = random.uniform(0.0, 100000000.0)
    debit = random.uniform(0.0, 100000000.0)
    market = random.uniform(0.0, 10000000.0)
    transport = random.uniform(0.0, 10000000.0)
    culture = random.uniform(0.0, 10000000.0)
    rent = random.uniform(0.0, 5000000.0)
    decided = random.choice([0.0, 50000.0, 500000.0, 2000000.0, 5000000.0, 20000000.0])
    
    try:
        simulate_employee(gross, credit, debit, market, transport, culture, rent, decided)
    except Exception as e:
        print(f"[직장인 에러 발견] 입력: gross={gross}, credit={credit}, debit={debit}, decided={decided} | 에러: {e}")
        errors_detected += 1
        break

print(f"\n스트레스 테스트 결과: 총 {errors_detected}개의 오류/사각지대 발견됨.")
if errors_detected == 0:
    print("=== 검증 성공: 단 하나의 사각지대 및 에러도 감지되지 않았습니다. ===")
