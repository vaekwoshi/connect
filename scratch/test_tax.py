import json
import os

# 1. 세무 파라미터 정의 (2025/2026년 귀속 세법 기준)
TAX_BRACKETS = [
    {"min_limit": 0, "max_limit": 14000000, "rate": 0.06, "deduction": 0},
    {"min_limit": 14000000, "max_limit": 50000000, "rate": 0.15, "deduction": 1260000},
    {"min_limit": 50000000, "max_limit": 88000000, "rate": 0.24, "deduction": 5760000},
    {"min_limit": 88000000, "max_limit": 150000000, "rate": 0.35, "deduction": 15440000},
    {"min_limit": 150000000, "max_limit": 300000000, "rate": 0.38, "deduction": 19940000},
    {"min_limit": 300000000, "max_limit": 500000000, "rate": 0.40, "deduction": 25940000},
    {"min_limit": 500000000, "max_limit": 1000000000, "rate": 0.42, "deduction": 35940000},
    {"min_limit": 1000000000, "max_limit": float('inf'), "rate": 0.45, "deduction": 65940000}
]

# 근로소득공제 계산
def calculate_labor_deduction(gross_salary):
    if gross_salary <= 5000000:
        return gross_salary * 0.70
    elif gross_salary <= 15000000:
        return 3500000 + (gross_salary - 5000000) * 0.40
    elif gross_salary <= 45000000:
        return 7500000 + (gross_salary - 15000000) * 0.15
    elif gross_salary <= 100000000:
        return 12000000 + (gross_salary - 45000000) * 0.05
    else:
        return 14750000 + (gross_salary - 100000000) * 0.02

# 근로소득세액공제 계산
def calculate_labor_tax_credit(calculated_tax, gross_salary):
    if calculated_tax <= 1300000:
        credit = calculated_tax * 0.55
    else:
        credit = 715000 + (calculated_tax - 1300000) * 0.30
    
    # 한도 계산
    if gross_salary <= 33000000:
        limit = 740000
    elif gross_salary <= 70000000:
        limit = max(660000, 740000 - (gross_salary - 33000000) * 0.008)
    else:
        limit = max(500000, 660000 - (gross_salary - 70000000) * 0.50)
        
    return min(credit, limit)

# 기본 소득세 계산
def calculate_base_tax(taxable_income):
    if taxable_income <= 0:
        return 0
    for bracket in TAX_BRACKETS:
        if taxable_income <= bracket["max_limit"]:
            return int(taxable_income * bracket["rate"] - bracket["deduction"])
    return 0

# 4대보험 계산 (직장인 본인부담금 연간 총액)
def calculate_employee_four_insurances(gross_salary):
    monthly = gross_salary / 12.0
    # 국민연금 (2026 상반기 상한 6,370,000 기준)
    np_monthly = min(6370000, max(400000, monthly)) * 0.045
    # 건강보험 (상한 127,725,731 기준)
    hi_monthly = min(127725731, max(280667, monthly)) * 0.03595
    # 장기요양보험
    lt_monthly = hi_monthly * 0.1314
    # 고용보험
    ei_monthly = monthly * 0.009
    
    return int((np_monthly + hi_monthly + lt_monthly + ei_monthly) * 12)

# 카드 소득공제 계산
def calculate_card_deduction(gross_salary, credit_card, debit_card):
    threshold = gross_salary * 0.25
    total_spending = credit_card + debit_card
    if total_spending <= threshold:
        return 0
    
    # 신용카드를 우선적으로 문턱을 채우는 것으로 가정 (납세자에게 가장 유리)
    excess = total_spending - threshold
    if credit_card >= threshold:
        # 신용카드로 문턱을 다 채운 경우
        deductible_credit = (credit_card - threshold) * 0.15
        deductible_debit = debit_card * 0.30
    else:
        # 신용카드로 문턱을 다 못 채워 체크카드로 일부 문턱을 채운 경우
        deductible_credit = 0
        remaining_threshold = threshold - credit_card
        deductible_debit = (debit_card - remaining_threshold) * 0.30
        
    deduction = deductible_credit + deductible_debit
    
    # 카드 공제 한도
    if gross_salary <= 70000000:
        limit = 3000000
    else:
        limit = 2500000
        
    return int(min(deduction, limit))

# 1. 직장인 계산기 E2E
def run_employee(gross_salary, net_salary, credit_card, debit_card, pension_savings, monthly_rent, medical_expense, dependents=1):
    labor_ded = calculate_labor_deduction(gross_salary)
    labor_income = gross_salary - labor_ded
    
    # 소득공제
    four_ins = calculate_employee_four_insurances(gross_salary)
    personal_ded = dependents * 1500000
    card_ded = calculate_card_deduction(gross_salary, credit_card, debit_card)
    
    total_deductions = four_ins + personal_ded + card_ded
    taxable_income = max(0, labor_income - total_deductions)
    
    # 산출세액
    calc_tax = calculate_base_tax(taxable_income)
    
    # 세액공제
    labor_credit = calculate_labor_tax_credit(calc_tax, gross_salary)
    
    # 연금계좌세액공제
    pension_limit = min(9000000, pension_savings)
    pension_rate = 0.15 if gross_salary <= 55000000 else 0.12
    pension_credit = pension_limit * pension_rate
    
    # 월세세액공제 (총급여 8천만 원 이하 무주택 가정)
    rent_credit = 0
    if gross_salary <= 80000000:
        rent_limit = min(10000000, monthly_rent * 12)
        rent_rate = 0.17 if gross_salary <= 55000000 else 0.15
        rent_credit = rent_limit * rent_rate
        
    # 의료비세액공제 (총급여 3% 초과액의 15%, 한도 700만 원 가정)
    medical_threshold = gross_salary * 0.03
    medical_credit = 0
    if medical_expense > medical_threshold:
        medical_credit = min(7000000, (medical_expense - medical_threshold) * 0.15)
        
    total_credits = labor_credit + pension_credit + rent_credit + medical_credit
    determined_tax = max(0, calc_tax - total_credits)
    
    # 기납부세액 역산 (세전 - 세후 - 4대보험)
    prepaid_tax = max(0, gross_salary - net_salary - four_ins)
    
    final_tax = determined_tax - prepaid_tax
    
    return {
        "gross_salary": gross_salary,
        "labor_deduction": int(labor_ded),
        "labor_income": int(labor_income),
        "four_insurances": four_ins,
        "card_deduction": card_ded,
        "taxable_income": taxable_income,
        "calculated_tax": calc_tax,
        "determined_tax": int(determined_tax),
        "prepaid_tax": int(prepaid_tax),
        "final_tax": int(final_tax)
    }

# 2. 프리랜서 계산기 E2E (업종코드 940909 크리에이터 단순 64.1% / 기준 12.8%)
def run_freelancer(revenue, pension_savings, dependents=1):
    # 직전 연도 수입이 2,400만 미만이면 단순경비율(64.1%), 이상이면 기준경비율(12.8% + 단순배율 2.8 한도)
    is_simple = revenue < 24000000
    if is_simple:
        ded_expenses = revenue * 0.641
        business_income = revenue - ded_expenses
    else:
        # 증빙이 전혀 없는 경우의 추계과세 (단순경비율 한도 적용)
        income_base = revenue - (revenue * 0.128)
        income_cap = (revenue - (revenue * 0.641)) * 2.8
        business_income = min(income_base, income_cap)
        ded_expenses = revenue - business_income
        
    personal_ded = dependents * 1500000
    taxable_income = max(0, business_income - personal_ded)
    
    calc_tax = calculate_base_tax(taxable_income)
    
    # 프리랜서는 연금계좌세액공제 가능 (종합소득금액 4.5천만 원 기준 15%/12%)
    pension_limit = min(9000000, pension_savings)
    pension_rate = 0.15 if business_income <= 45000000 else 0.12
    pension_credit = pension_limit * pension_rate
    
    determined_tax = max(0, calc_tax - pension_credit)
    
    # 3.3% 중 소득세 분 3%
    prepaid_tax = revenue * 0.03
    
    final_tax = determined_tax - prepaid_tax
    
    return {
        "revenue": revenue,
        "is_simple": is_simple,
        "ded_expenses": int(ded_expenses),
        "business_income": int(business_income),
        "taxable_income": int(taxable_income),
        "calculated_tax": calc_tax,
        "determined_tax": int(determined_tax),
        "prepaid_tax": int(prepaid_tax),
        "final_tax": int(final_tax)
    }

# 3. N잡러 계산기 E2E
def run_combined(gross_salary, net_salary, credit_card, debit_card, pension_savings, monthly_rent, medical_expense, freelancer_revenue, dependents=1):
    # 근로파트
    labor_ded = calculate_labor_deduction(gross_salary)
    labor_income = gross_salary - labor_ded
    
    # 사업파트 (2,400만 기준 단순/기준경비율 판정)
    is_simple = freelancer_revenue < 24000000
    if is_simple:
        freelancer_expenses = freelancer_revenue * 0.641
        freelancer_income = freelancer_revenue - freelancer_expenses
    else:
        income_base = freelancer_revenue - (freelancer_revenue * 0.128)
        income_cap = (freelancer_revenue - (freelancer_revenue * 0.641)) * 2.8
        freelancer_income = min(income_base, income_cap)
        freelancer_expenses = freelancer_revenue - freelancer_income
        
    # 종합소득금액
    global_income = labor_income + freelancer_income
    
    # 소득공제
    four_ins = calculate_employee_four_insurances(gross_salary)
    personal_ded = dependents * 1500000
    # N잡러 신용카드 문턱은 근로소득 총급여의 25% 적용
    card_ded = calculate_card_deduction(gross_salary, credit_card, debit_card)
    
    total_deductions = four_ins + personal_ded + card_ded
    taxable_income = max(0, global_income - total_deductions)
    
    calc_tax = calculate_base_tax(taxable_income)
    
    # 세액공제
    # 근로소득세액공제는 종합소득 산출세액 중 근로소득점유비율 만큼 안분
    base_labor_credit = calculate_labor_tax_credit(calc_tax, gross_salary)
    labor_credit = base_labor_credit * (labor_income / global_income) if global_income > 0 else 0
    
    # 연금계좌세액공제 (종합소득금액 기준)
    pension_limit = min(9000000, pension_savings)
    pension_rate = 0.15 if global_income <= 45000000 else 0.12
    pension_credit = pension_limit * pension_rate
    
    # 월세공제 (근로소득자이므로 적용 가능)
    rent_credit = 0
    if gross_salary <= 80000000:
        rent_limit = min(10000000, monthly_rent * 12)
        rent_rate = 0.17 if gross_salary <= 55000000 else 0.15
        rent_credit = rent_limit * rent_rate
        
    # 의료비공제 (근로소득자이므로 적용 가능)
    medical_threshold = gross_salary * 0.03
    medical_credit = 0
    if medical_expense > medical_threshold:
        medical_credit = min(7000000, (medical_expense - medical_threshold) * 0.15)
        
    total_credits = labor_credit + pension_credit + rent_credit + medical_credit
    determined_tax = max(0, calc_tax - total_credits)
    
    # 기납부세액 = 직장 기납부세액(세전 - 세후 - 4대보험) + 프리랜서 원천세액(3%)
    prepaid_labor = max(0, gross_salary - net_salary - four_ins)
    prepaid_freelancer = freelancer_revenue * 0.03
    prepaid_tax = prepaid_labor + prepaid_freelancer
    
    final_tax = determined_tax - prepaid_tax
    
    return {
        "labor_income": int(labor_income),
        "freelancer_income": int(freelancer_income),
        "global_income": int(global_income),
        "taxable_income": int(taxable_income),
        "calculated_tax": int(calc_tax),
        "determined_tax": int(determined_tax),
        "prepaid_tax": int(prepaid_tax),
        "final_tax": int(final_tax)
    }

# ----------------- 테스트 시나리오 구동 -----------------

# 10개 직장인 가상 케이스
employee_cases = [
    # gross, net, card_c, card_d, pension, rent, medical, dependents
    (30000000, 27000000, 5000000, 5000000, 3000000, 0, 0, 1),
    (50000000, 42000000, 10000000, 10000000, 6000000, 0, 0, 1),
    (75000000, 60000000, 15000000, 15000000, 9000000, 500000, 1000000, 1),
    (100000000, 75000000, 20000000, 20000000, 9000000, 0, 2000000, 2),
    (40000000, 34500000, 4000000, 4000000, 0, 400000, 0, 1),
    (60000000, 50000000, 8000000, 10000000, 4000000, 0, 500000, 3),
    (24000000, 22000000, 3000000, 2000000, 0, 0, 0, 1),
    (85000000, 67000000, 10000000, 15000000, 5000000, 0, 0, 2),
    (48000000, 40500000, 6000000, 6000000, 0, 600000, 0, 1),
    (120000000, 87000000, 15000000, 20000000, 9000000, 0, 0, 4)
]

# 10개 프리랜서 가상 케이스
freelancer_cases = [
    # revenue, pension_savings, dependents
    (20000000, 1200000, 1),
    (30000000, 3000000, 1),
    (45000000, 6000000, 1),
    (60000000, 9000000, 1),
    (80000000, 9000000, 1),
    (15000000, 0, 1),
    (28000000, 2000000, 1),
    (50000000, 4000000, 2),
    (100000000, 9000000, 1),
    (150000000, 9000000, 2)
]

# 10개 N잡러 가상 케이스
combined_cases = [
    # gross, net, card_c, card_d, pension, rent, medical, free_rev, dependents
    (30000000, 27000000, 5000000, 5000000, 3000000, 0, 0, 10000000, 1),
    (50000000, 42000000, 10000000, 10000000, 6000000, 0, 0, 20000000, 1),
    (70000000, 56000000, 12000000, 12000000, 9000000, 400000, 0, 30000000, 2),
    (90000000, 69000000, 15000000, 15000000, 9000000, 0, 1000000, 40000000, 1),
    (40000000, 34500000, 4000000, 4000000, 2000000, 300000, 0, 15000000, 1),
    (60000000, 50000000, 8000000, 10000000, 4000000, 0, 500000, 25000000, 3),
    (24000000, 22000000, 3000000, 2000000, 0, 0, 0, 8000000, 1),
    (80000000, 63000000, 10000000, 15000000, 5000000, 0, 0, 35000000, 2),
    (48000000, 40500000, 6000000, 6000000, 3000000, 500000, 0, 18000000, 1),
    (110000000, 80000000, 15000000, 20000000, 9000000, 0, 0, 50000000, 4)
]

print("=== EMPLOYEE TESTS ===")
for i, c in enumerate(employee_cases):
    res = run_employee(*c)
    print(f"CASE {i+1} | Gross: {res['gross_salary']:,} | CalcTax: {res['calculated_tax']:,} | DetTax: {res['determined_tax']:,} | Prepaid: {res['prepaid_tax']:,} | Final: {res['final_tax']:,}")

print("\n=== FREELANCER TESTS ===")
for i, c in enumerate(freelancer_cases):
    res = run_freelancer(*c)
    print(f"CASE {i+1} | Revenue: {res['revenue']:,} | CalcTax: {res['calculated_tax']:,} | DetTax: {res['determined_tax']:,} | Prepaid: {res['prepaid_tax']:,} | Final: {res['final_tax']:,}")

print("\n=== COMBINED TESTS ===")
for i, c in enumerate(combined_cases):
    res = run_combined(*c)
    print(f"CASE {i+1} | Income: {res['global_income']:,} | CalcTax: {res['calculated_tax']:,} | DetTax: {res['determined_tax']:,} | Prepaid: {res['prepaid_tax']:,} | Final: {res['final_tax']:,}")
