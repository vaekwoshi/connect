# Build Log
*Owned by Architect. Updated by Builder after each step.*

---

## Current Status

**Active step:** Step 2 — CLEAR, awaiting Project Owner go-ahead to commit
**Last cleared:** Step 1 — 2026-07-10, 커밋 `bbc7d75`
**Pending deploy:** NO (프로덕션 배포/APK 빌드 없음)

---

## Step History

### Step 2 — 지급명세서 확인 알림(KG-6c) + 건강보험 미가입 정기 경고(KG-6d) — BUILT (review pending)
*Date: 2026-07-10*

Files changed:
- `lib/core/notifications/system_reminder_catalog.dart` — `payment_report` 그룹 추가, `sys_payment_report_check`(notifId 1004, 매년 3/12, business만) 카탈로그 항목 신설
- `lib/core/notifications/event_reminder_prefs.dart` — `freelancer_health_uninsured` 기본값(9:00) 등록
- `lib/core/notifications/reminder_scheduler.dart` — `checkFreelancerHealthUninsured({required healthEnrolled})` 신설(idFreelancerHealthUninsured=2006), `checkTaxReserveShortfall`과 동일 패턴(조건 해소 시 자동 취소)
- `lib/ui/screens/home_screen.dart` — `_loadCurrentMonthIncome`에 프리랜서 전용 분기 추가, 프로필의 `health_enrolled` 조회 후 `checkFreelancerHealthUninsured` 호출
- `lib/ui/screens/reminder_list_screen.dart` — "기본 제공" 섹션에 `freelancer_health_uninsured` 토글 행 추가(프리랜서에게만 표시)

Decisions made:
- KG-6c 일정 3/12(Project Owner 확정), 문구에 홈택스 확인 경로 포함(Project Owner 요청)
- KG-6d는 프리랜서 전용(N잡러 제외 — 근로자로서 이미 직장 건강보험 가입 전제)
- KG-7(tax_reserve_shortfall UI 토글 누락), KG-8(이벤트형 notifId 대역 충돌 가능성) — 리서치 중 발견, 로그만 하고 미수정(범위 밖)

Verification: `flutter test test/engine_regression_test.dart` 53건 전원 통과. `flutter analyze` — 이번 변경으로 인한 신규 이슈 없음(기존 `activeColor` deprecated/미관련 `mounted` 경고 3건은 이번 수정 이전부터 존재).
Reviewer findings: 대기 중
Deploy: NO

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
- ~~**KG-6c** — 지급명세서 발급 확인 알림 없음~~ — RESOLVED, Step 2 (아래)
- ~~**KG-6d** — 건강보험 지역가입자 전환 안내 없음~~ — RESOLVED, Step 2 (아래)
- **KG-7** — `tax_reserve_shortfall` 이벤트형 리마인더가 `reminder_list_screen.dart` "기본 제공" 토글 UI에 등록 안 돼 있음(예산/미기록 넛지 4종만 등록됨) — 사용자가 끄거나 시각 편집 불가. Step 2 리서치 중 발견, 이번 스텝 범위 밖.
- **KG-8** — 이벤트형 리마인더 고정 notifId(2002/2004/2005/2006)가 커스텀 리마인더 notifId 체계(`_notifBase=2000 + reminder.id`)와 같은 대역이라, 사용자 커스텀 리마인더 id가 2·4·5·6이면 이론상 충돌 가능. Step 2 리서치 중 발견, 스킴 변경은 범위 밖.

---

## Architecture Decisions

- 온디바이스 전용 — WebView 금지, 네트워크 호출 금지 — 2026-07-03
- AppTheme v4 Blueprint: border-radius ≤ 4px (계산기 화면 예외 있음), 그림자 없음, BottomSheet·ElevatedButton·OutlinedButton 금지 — 2026-07-03
- 5탭 IA: 홈|혜택|상품|계산기|전체 — 2026-07-03
- 아이콘 재제작 + IA 전면 재설계는 모든 기능 완성 후 마지막 — 2026-07-03
