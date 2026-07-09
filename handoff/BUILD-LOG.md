# Build Log
*Owned by Architect. Updated by Builder after each step.*

---

## Current Status

**Active step:** Step 4b/4c COMPLETE & 시각 검증 완료 (직장인·프리랜서 양쪽 확인). 원격 push는 별도 보류 항목 — 미실행.
**Last cleared:** Step 4b/4c — 2026-07-10
**Pending deploy:** NO (프로덕션 배포/APK 빌드 없음)

---

## Step History

### Step 4b/4c — 목록 탭 제거, 결제칩·고정지출 AppBar 통합, 뷰탭+범례 하단바 이동 — COMPLETE
*Date: 2026-07-10*

`/grilling` 세션으로 사용자와 함께 설계 확정 후 구현. 요지: 캘린더 위 상시 크롬을 최소화해 "달력이 화면을 지배해야 한다"는 요구 충족.

Files changed:
- `lib/ui/screens/month_list_screen.dart`(신규) — 목록 뷰를 독립 fullscreen 화면으로 추출. 월 라벨("2026. 7") 탭으로 진입.
- `lib/ui/screens/payment_management_screen.dart`(신규) — 월급날·카드 결제일·고정지출을 한 화면으로 통합. AppBar "관리"(tune) 아이콘으로 진입. `showPayday`(LedgerProfile.showsPaydayChip)로 프리랜서는 월급날 섹션 숨김.
- `lib/ui/screens/expense_calendar_screen.dart` — `_buildPaymentStrip`/`_showPaydayPicker`/`_showAddCardDialog`/`_showCardOptions`/목록뷰 관련 메서드 전부 제거(위 두 신규 파일로 이관). `_activeView` 3개로 재번호(0=달력,1=분석,2=연간). 뷰탭+범례(색 점만, 고정지출 링크는 관리 화면으로 이관)를 `bottomNavigationBar`로 이동, 달력 탭일 때만 범례 노출. 요약바·적립카드는 달력 탭에서만 노출(`_activeView == 0`).

Verification: `flutter analyze` 신규 이슈 없음(기존 lint 4건만), `flutter test` 53건 통과. **웹 프리뷰 실사용 검증**: 접근성 시맨틱 트리를 실제 PointerEvent로 열어 클릭 내비게이션 확보 → 직장인(월급 섹션 노출)·프리랜서(월급 섹션 숨김, 적립카드 노출) 양쪽에서 가계부 진입→관리 화면→월 목록 화면까지 스크린샷으로 실측 확인.
Reviewer findings: 셀프 리뷰 — 국소적 이동/추출 위주라 Must Fix 없음.
Deploy: NO

처음엔 Flutter 웹 캔버스 렌더 때문에 프리뷰 도구로 클릭 내비게이션이 안 되는 줄 알았으나, `flt-semantics-placeholder`를 실제 PointerEvent(pointerdown/up)로 클릭하면 접근성 시맨틱 트리가 정상적으로 열려 이후 모든 버튼에 실제 클릭 내비게이션이 가능함을 확인(단순 DOM `.click()`이 아니라 pointer 이벤트가 필요했음). 이 방법으로 3유형 전환·가계부 진입·적립카드 펼침/접힘까지 전부 스크린샷으로 실측 검증.

Files changed:
- `lib/ui/screens/expense_calendar_screen.dart` — `_reserveCardExpanded` 상태 추가(기본 false). `_buildReserveCard`를 헤더(아이콘+라벨+접혔을 때 "지금 써도 되는 돈" 요약값+shevron)를 탭하면 펼쳐지는 구조로 재작성. 펼쳤을 때 내용(세금/보험/지금 써도 되는 돈/업종코드 안내)은 기존과 동일.

Verification: `flutter analyze`/`flutter test` 클린(53건 통과). **웹 프리뷰로 실제 확인**: 프리랜서 유형 진입 시 접힌 카드가 "이번 달 세금·보험 적립(예상)  0원 ⌄" 한 줄로 축소됨을 스크린샷 확인, 탭 시 기존 4줄 상세로 정상 펼쳐짐 확인.
Reviewer findings: 셀프 리뷰 — 변경이 국소적(단일 위젯 메서드 + 상태 필드 1개)이라 Must Fix 없음.
Deploy: NO

### Step 4b/4c(범례 통합, 뷰탭 정리) — 미착수, 다음으로 보류(사용자 확인 후)

### Step 4 — 가계부 화면 크롬 7층→4층 — 원래 BLOCKED로 기록했던 시각 검증 문제는 위 4a에서 해결됨(기록 보존용)
*Date: 2026-07-10*

~~착수해 `flutter build web` + `sekkeul-web` 프리뷰까지 띄웠으나, **Flutter 웹이 캔버스 렌더라 프리뷰 도구로 UI 클릭 내비게이션 불가**~~ → 해결됨, 위 4a 참고.

### Step 3 — LedgerProfile 도입: 흩어진 userType 분기 통합 — COMPLETE (커밋 `12cca53`)
*Date: 2026-07-10*

Files changed:
- `lib/core/data/ledger_profile.dart` (신규) — 유형별 역량 선언 값 객체 + `LedgerProfile.of(userType)` 단일 진실 원천(8개 필드).
- `lib/ui/screens/day_entry_screen.dart` — `isBusinessUser` 생성자 prop 제거하고 `_profile = LedgerProfile.of(widget.userType)`에서 파생. 사업경비/소득토글 노출/근로소득칩/원천징수 기본값을 profile 필드로 교체. 소득 칩은 `_profile.incomeTypes`로 렌더.
- `lib/ui/screens/expense_calendar_screen.dart` — `_profile` getter 추가, `_isBusinessUser`를 `_profile.tracksBusinessExpense`로 위임. 소득유형 기본값→`_profile.defaultIncomeType`, 원천징수→`_profile.withholdingDefault`, 월급날 칩→`_profile.showsPaydayChip`으로 교체. `DayEntryScreen` 호출부의 `isBusinessUser` 인자 제거.

Decisions made:
- **home_screen.dart는 이번 스텝 범위에서 제외** — home의 `_isEmployee`/유형 분기는 홈 대시보드 카드·알림 스케줄링 로직이라 가계부 화면과 성격이 다름. 블라스트 반경을 가계부로 한정. KG-9로 후속 기록.
- 각 치환은 논리 동치(진리표 동일) 확인: `_isBusinessUser`≡`tracksBusinessExpense`, 소득기본값·원천징수·월급날칩 전부 유형별로 기존과 동일.

Verification: `flutter analyze`(ledger_profile·day_entry·calendar) — 신규 이슈 없음(calendar의 style lint 4건은 미변경 영역 1902/2279행의 기존 것). `flutter test` 53건 통과. **미완: 3유형 웹 프리뷰 스크린샷 대조(동작 변화 0 최종 확인) — 사용자 확인 후 진행.**
Reviewer findings: 대기 중
Deploy: NO

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
- **KG-9** — `home_screen.dart`의 `_isEmployee`/유형 문자열 분기가 아직 LedgerProfile로 통합 안 됨(Step 3에서 가계부 두 화면만 우선 정리, 홈은 블라스트 반경 관리 위해 보류) — 2026-07-10

---

## Architecture Decisions

- 온디바이스 전용 — WebView 금지, 네트워크 호출 금지 — 2026-07-03
- AppTheme v4 Blueprint: border-radius ≤ 4px (계산기 화면 예외 있음), 그림자 없음, BottomSheet·ElevatedButton·OutlinedButton 금지 — 2026-07-03
- 5탭 IA: 홈|혜택|상품|계산기|전체 — 2026-07-03
- 아이콘 재제작 + IA 전면 재설계는 모든 기능 완성 후 마지막 — 2026-07-03
