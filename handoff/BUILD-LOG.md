# Build Log
*Owned by Architect. Updated by Builder after each step.*

---

## Current Status

**Active step:** Step 1 — CLEAR, awaiting Project Owner go-ahead to commit
**Last cleared:** Step 0.5 (프리랜서 4대보험 적립 카드 등, TMT 절차 밖에서 진행된 대량 작업) — 2026-07-10, 커밋 `d0e799a`
**Pending deploy:** NO

---

## Step History

### Step 1 — 기록 넛지 문구 userType 분기 + 5월 종합소득세 알림 3.3%/8.8% 정산 안내 — BUILT (review pending)
*Date: 2026-07-10*

Files changed:
- `lib/core/notifications/custom_reminder_service.dart` — `ensureRecordSeed`에 `userType` 파라미터 추가, 프리랜서는 "가계부에 오늘 기록해볼까요?", 그 외(직장인·N잡러)는 기존 "월급날이에요!..." 유지. 이미 시드된 프리랜서 유저의 옛 제목을 1회 갱신하는 fix-up 포함(시각·주기는 유지).
- `lib/core/notifications/reminder_scheduler.dart` — `scheduleAll`에서 `ensureRecordSeed` 호출 시 `userType` 전달. `sys_may_start` 카탈로그 알림에 프리랜서·N잡러 대상 3.3%/8.8% 원천징수 정산 안내 append(`_appendWithholdingNote`, `_appendReserveStatus`와 동일 패턴).

Decisions made:
- KG-6c(지급명세서 발급 확인), KG-6d(건강보험 지역가입자 전환 안내)는 세무 정책 디테일 확인 전까지 이번 스텝 범위 밖 유지(브리프대로).

Verification: `flutter test test/engine_regression_test.dart` 53건 전원 통과, `flutter analyze`로 수정한 2개 파일 이상 없음 확인.
Reviewer findings: 대기 중
Deploy: NO

### Step 0.5 — 세금·4대보험 적립 카드 / 가계부 풀스크린 전환 / 종부세·재산세 계산기 — COMPLETE (TMT 절차 밖 진행)
*Date: 2026-07-05 ~ 2026-07-07, 커밋 2026-07-10 (`d0e799a`)*

TMT 브리핑/리뷰 사이클 없이 진행된 작업 — 상세 내용은 요약.md 참고. 회귀테스트 53건 통과 확인 후 커밋.

Files changed: `reserve_estimator.dart`(신규), `day_entry_screen.dart`(신규), `property_tax_screen.dart`(신규), `withholding_calc_screen.dart`(신규), `annual_backfill_screen.dart`(신규), `my_info_screen.dart`, `notification_history.dart`, `db_helper.dart`(v32) 외 다수.

Reviewer findings: 없음 (TMT 도입 전/외 작업)
Deploy: 로컬 커밋만, 프로덕션 배포 아님

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

- ~~**KG-1** — 종부세·재산세 계산기 미구현~~ — RESOLVED 2026-07-07 (`property_tax_screen.dart`)
- ~~**KG-2** — 혜택탭 상세 내용 미완성~~ — RESOLVED (9개 카테고리 전체 완성, 요약.md 참고)
- ~~**KG-3** — 리마인더·알림 기능 없음~~ — RESOLVED (커밋 `35178cd`, `d0e799a`)
- **KG-4** — 개인정보처리방침 웹 페이지 없음 — OPEN, GitHub Pages Actions 빌드가 Checkout 단계에서 실패 중 (원인 미확정). 로컬에 미push 커밋 있음. **사용자 지시로 보류 — 명시적 요청 시에만 재개.**
- ~~**KG-5** — 양식탭 PDF 연동 없음~~ — RESOLVED (`assets/forms/*.pdf` 18종 추가, 커밋 `d0e799a`)
- ~~**KG-6a** — 기록 넛지 문구 프리랜서 어색함~~ / ~~**KG-6b** — 5월 정산 3.3%/8.8% 안내 없음~~ — **Step 1로 착수 (아래)**
- **KG-6c** — 지급명세서(원천징수영수증) 발급 확인 알림 없음 — 정확한 제출기한(다음해 2월말 지급명세서 / 반기 간이지급명세서 등) 확인 필요, 착수 보류
- **KG-6d** — 건강보험 지역가입자 전환 안내 없음 — 트리거 시점·문구 정책 결정 필요, 착수 보류

---

## Architecture Decisions

- 온디바이스 전용 — WebView 금지, 네트워크 호출 금지 — 2026-07-03
- AppTheme v4 Blueprint: border-radius ≤ 4px (계산기 화면 예외 있음), 그림자 없음, BottomSheet·ElevatedButton·OutlinedButton 금지 — 2026-07-03
- 5탭 IA: 홈|혜택|상품|계산기|전체 — 2026-07-03
- 아이콘 재제작 + IA 전면 재설계는 모든 기능 완성 후 마지막 — 2026-07-03
