def calc(tax_base):
    # Pension 4.5%
    pension = int((tax_base * 0.045) // 10 * 10)
    # Health 3.545%
    health = int((tax_base * 0.03545) // 10 * 10)
    # LTC 12.95% of health
    ltc = int((health * 0.1295) // 10 * 10)
    # Employment 0.9%
    emp = int((tax_base * 0.009) // 10 * 10)
    
    total_ins = pension + health + ltc + emp
    return pension, health, ltc, emp, total_ins

for tb in range(1000000, 2320864, 10):
    p, h, l, e, total = calc(tb)
    if total <= 111160 and total >= 111000:
        print(f"Tax Base: {tb}, Total Ins: {total}")
