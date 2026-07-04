# Build Log
*Owned by Architect. Updated by Builder after each step.*

---

## Current Status

**Active step:** 다음 스텝 미정 — Project Owner 확인 필요
**Last cleared:** Step 0 (초기 기능 구현 일괄 완료) — 2026-07-04
**Pending deploy:** NO

---

## Step History

### Step 0 — 계산기 탭 25개 계산기 구현 — COMPLETE
*Date: 2026-07-04 (이전 세션 누적)*

Files changed:
- `lib/ui/screens/calculator_screen.dart` — 5카테고리 25계산기 라우팅
- `lib/ui/screens/salary_net_screen.dart`, `four_insurance_screen.dart`, `severance_pay_screen.dart`, `weekly_holiday_pay_screen.dart`, `freelancer_book_screen.dart`, `unemployment_benefit_screen.dart`, `national_pension_timing_screen.dart` — 급여·근로 계산기 7개
- `lib/ui/screens/earned_income_tax_credit_screen.dart`, `pension_calculator_screen.dart`, `insurance_premium_screen.dart`, `dependent_deduction_screen.dart`, `financial_income_screen.dart`, `isa_tax_benefits_screen.dart` — 세금·연금·환급 계산기 6개
- `lib/ui/screens/didimdol_loan_screen.dart`, `beotimmok_loan_screen.dart`, `jeonse_insurance_screen.dart`, `monthly_rent_tax_credit_screen.dart` — 주거·부동산 계산기 4개
- `lib/ui/screens/loan_interest_screen.dart`, `loan_schedule_screen.dart`, `compound_interest_screen.dart`, `savings_calculator_screen.dart`, `jeonse_vs_wolse_screen.dart` — 대출·저축 계산기 5개
- `lib/ui/screens/housing_subscription_screen.dart`, `acquisition_tax_screen.dart`, `capital_gains_tax_screen.dart`, `inheritance_gift_tax_screen.dart` — 부동산 세금 계산기 4개 (종부세·재산세는 준비중)

Decisions made:
- 종부세·재산세는 `builder: null` ("준비 중") 처리
- AppTheme v4 Blueprint 디자인 시스템 전면 적용

Reviewer findings: 없음 (TMT 도입 전 작업)
Deploy: 확인됨

---

## Known Gaps

- **KG-1** — 종부세·재산세 계산기 미구현 (`calculator_screen.dart` line 81, builder null) — 2026-07-04
- **KG-2** — 혜택탭 상세 내용 미완성 — 2026-07-04
- **KG-3** — 리마인더·알림 기능 없음 (flutter_local_notifications 매니페스트 수동 선언 필요) — 2026-07-04
- **KG-4** — 개인정보처리방침 웹 페이지 없음 — 2026-07-04
- **KG-5** — 양식탭 PDF 연동 없음 (PDF 파일 미제공) — 2026-07-04

---

## Architecture Decisions

- 온디바이스 전용 — WebView 금지, 네트워크 호출 금지 — 2026-07-03
- AppTheme v4 Blueprint: border-radius ≤ 4px (계산기 화면 예외 있음), 그림자 없음, BottomSheet·ElevatedButton·OutlinedButton 금지 — 2026-07-03
- 5탭 IA: 홈|혜택|상품|계산기|전체 — 2026-07-03
- 아이콘 재제작 + IA 전면 재설계는 모든 기능 완성 후 마지막 — 2026-07-03
