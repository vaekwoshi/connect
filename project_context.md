# 세끌 (Sekkeul) — PROJECT CONTEXT

> Local-First Tax Simulator App for Employee and Freelancers
> **▶ 현재 진행 로드맵·엔진 상태·홈 재설계는 문서 맨 아래 [§A 작업 로드맵] 참조 (대화창 공유 SSOT).**

---

## 앱 목표

직장인·프리랜서·N잡러(투잡)가 복잡한 세금 계산 없이도 **연말정산·종합소득세·절세 전략**을 스스로 파악할 수 있도록 돕는 온디바이스 세금 도우미 앱. 민감한 소득 정보는 서버에 전송하지 않고 기기 내 SQLite에만 저장한다.

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프레임워크 | Flutter (Dart) |
| 로컬 DB | sqflite (SQLite, DB version **v13**) |
| 국제화 | intl |
| 알림 | flutter_local_notifications |
| 패키지 이름 | `secul` (`pubspec.yaml`) |

---

## 사용자 유형 (user_type)

| 유형 | 주요 기능 |
|------|---------|
| **직장인** | 연말정산 진단, 경정청구 시뮬레이션, 5월 종합소득세 가이드 |
| **N잡러** | 이중근로 합산 연말정산, 근로+사업소득 합산 종소세 계산 |
| **프리랜서** | 3.3% 원천징수 후 5월 종소세 신고, 경비율 계산, 노란우산공제 |

---

## 프로젝트 구조

```
lib/
├── main.dart
├── core/
│   ├── data/
│   │   ├── db_helper.dart          # SQLite 인터페이스 (v11)
│   │   ├── app_mode.dart           # 데이터 수집 모드 (제1/제2모드)
│   │   ├── expense_item.dart       # 지출 항목 모델
│   │   ├── occupation_data.dart    # 프리랜서 업종코드/경비율 데이터
│   │   └── health_insurance_data.dart
│   ├── tax_engine/
│   │   ├── employee_tax.dart       # 직장인 연말정산 계산 엔진
│   │   ├── freelancer_tax.dart     # 프리랜서 종합소득세 계산 엔진
│   │   ├── combined_tax.dart       # N잡러 합산소득세 계산 엔진
│   │   ├── insurance_engine.dart   # 4대보험 계산
│   │   └── tax_rates.dart          # 세율 테이블 (2025 귀속)
│   └── security/
│       ├── crypto_helper.dart      # 지출 내역 텍스트 암호화
│       └── notification_helper.dart
└── ui/
    ├── theme/app_theme.dart
    ├── components/bounce_card.dart
    └── screens/
        ├── home_screen.dart            # 메인 홈 (유형 선택 + 소득/지출 카드)
        ├── profile_input_screen.dart   # 프로필 입력 마법사 (PageView)
        ├── year_end_tax_screen.dart    # 직장인 연말정산 진단
        ├── tax_simulator_screen.dart   # 세금 시뮬레이터 (경정청구)
        ├── tax_annual_report_screen.dart
        ├── income_calendar_screen.dart # 월별 소득 기록
        ├── expense_calendar_screen.dart
        ├── ledger_screen.dart          # 지출 가계부
        ├── employee_input_screen.dart
        ├── freelancer_input_screen.dart
        ├── freelancer_book_screen.dart
        ├── onboarding_screen.dart
        ├── data_mode_screen.dart
        ├── expense_target_screen.dart
        ├── tax_persona_question_screen.dart
        ├── secret_tax_guide_screen.dart
        ├── tax_record_list_screen.dart
        └── tax_report_form_screen.dart

지식_변환/               # 세무 지식 베이스 (Gemini 전용 Ground Truth)
├── JSON/                # 구조화된 세무 지식 JSON
└── 마크다운/            # 동일 내용 마크다운 버전
```

---

## DB 스키마 (v12)

### `user_profile`
| 컬럼 | 타입 | 설명 |
|------|------|------|
| user_type | TEXT | 직장인 / N잡러 / 프리랜서 |
| gross_income | REAL | 연봉(연소득) |
| dependents | INTEGER | 부양가족 수 |
| is_married | INTEGER | 배우자 여부 |
| is_spouse_dependent | INTEGER | 배우자 기본공제 대상 여부 |
| has_spouse_disability | INTEGER | 배우자 장애인 여부 |
| has_self_disability | INTEGER | 본인 장애인 여부 |
| disabled_dependent_count | INTEGER | 장애인 부양가족 수 |
| **has_elderly_70plus** | INTEGER | 경로우대 (70세 이상 부양가족) |
| **is_female_head** | INTEGER | 부녀자공제 해당 여부 |
| **is_single_parent** | INTEGER | 한부모공제 해당 여부 |
| **wedding_year** | INTEGER | 혼인신고 연도 (2024~2026이면 혼인세액공제 자동 판단) |
| **children_count_8plus** | INTEGER | 8세 이상 자녀 수 (자녀세액공제 wizard 자동 로드) |
| **newborn_count** | INTEGER | 당해 출산·입양 수 |
| is_monthly_rent | INTEGER | 월세 공제 여부 |
| monthly_rent | REAL | 월세액 |
| decided_tax | REAL | 결정세액 (연말정산 진단 데이터) |
| yellow_umbrella | REAL | 노란우산공제 납입액 |
| monthly_income | REAL | 이번 달 수령액 |
| data_mode | TEXT | 제1모드 / 제2모드 |
| expense_target | REAL | 이번 달 지출 목표 |

### `expenses`
암호화된 지출 내역 (id, date, end_date, amount, content, category)

### `tax_records`
세무 기록부 (연도별 세금 계산 결과 저장)

### `monthly_income_records`
월별 소득 기록 (year, month, amount) PK(year, month) — **소득 입력의 단일 진실원(SSOT)**
API: `setMonthlyIncome` / `getMonthlyIncomesForYear` / `deleteMonthlyIncome` (`db_helper.dart`)

---

## 세금 계산 엔진 주요 메서드

### `employee_tax.dart`
- `calculateAnnualTax()` — 연말정산 전체 흐름 (소득공제 → 세액공제 → 결정세액)
- `calculateAdditionalPersonalDeduction()` — 추가 인적공제 합산
  - `hasElderly70Plus` → +100만원
  - `isSingleFemaleHead` → +50만원 (한부모와 중복 시 한부모 우선)
  - `isSingleParent` → +100만원
- `calculateMonthlyInsurance()` — 월 4대보험 계산
- `calculateSpecialDeductions()` — 의료비·교육비·기부금·월세 특별공제

### `freelancer_tax.dart`
- `calculateFreelancerTax()` — 단순/기준경비율 추계신고 또는 실제 기장

### `combined_tax.dart`
- `calculateCombinedTax()` — 근로+사업소득 합산 종합소득세

---

## 데이터 수집 모드

| 모드 | 방식 |
|------|------|
| **제1모드** | 홈택스 간소화 자료를 앱에 직접 입력 → 정확한 연말정산 계산 |
| **제2모드** | 앱 내 소득·지출 기록 → 추정치 기반 절세 시뮬레이션 |

---

## 지식 베이스 (`지식_변환/`)

Gemini가 `/지식` 명령으로 참조하는 세무 Ground Truth. 인터넷 검색 없이 이 폴더 내용만으로 답변.

### 직장인
- `직장인_연말정산_FAQ.json/md` — 25개 Q&A
- `직장인_특별공제_가이드.json/md`
- `2025_연말정산_공제율_정답지.json/md`
- `직장인_5월_종합소득세_계산기.json/md`
- `직장인_4대보험_가이드.json/md`

### N잡러
- `N잡러_합산신고_FAQ.json/md` — 20개 Q&A
- `N잡러_합산소득세_계산기.json/md`
- `N잡러_4대보험_가이드.json/md`
- `N잡러_금융임대_가이드.json/md`

### 프리랜서
- `프리랜서_세금신고_FAQ.json/md` — 20개 Q&A
- `프리랜서_종소세_계산기.json/md`
- `프리랜서_4대보험_가이드.json/md`
- `프리랜서_특고_가이드.json/md`
- `2025년 귀속 경비율.json/md`

### 공통
- `홈택스_연말정산_이용가이드.json/md`
- `12개_공식서식_완전맵.json`
- `계산사례_엔진테스트.json` — 국세청 공식 35개 계산 사례

---

## 핵심 설계 원칙

1. **로컬 퍼스트** — 민감 소득 데이터는 기기 밖으로 나가지 않는다
2. **지식 격리** — Gemini는 지식_변환/ 폴더만을 세법 근거로 사용 (외부 검색·일반 지식 배제)
3. **유형별 분기** — 직장인/N잡러/프리랜서 UI와 계산 로직이 user_type 기준으로 명확히 분리
4. **세금 계산 정확성** — 국세청 공식 계산 사례 35개를 엔진 테스트 기준으로 사용

---
---

# §A 작업 로드맵 (2026-06 진행, 대화창 공유 SSOT)

> 작업 완료 시 아래 체크박스를 **즉시 갱신**한다. 마지막 갱신: 2026-06-18 23:00

## A-1. 이번 작업의 동기
홈이 토스처럼 간단해야 하는데 **연말정산 진입점이 4곳에 중복**(시즌배너·유형별카드·그리드·도구시트)되고, **소득·지출 카드의 소득 직접입력이 달력 기록과 충돌**하는 버그가 있다. 엔진은 이미 완성도가 높으므로(아래 A-2) 병목은 홈 UI다.

### 앱 핵심 목표 (설계 기준점)
- **토스처럼 간단**: 모든 연령대, 한 화면에 핵심만.
- **현실 인식**: 사용자가 소득·지출·세금을 현실적으로 자각.
- **핵심 3축**: ① 공제 혜택 최대화 가이드 ② 정확한 계산(검증 엔진만) ③ 민감항목은 5월 종소세 신고로 분리 안내.
- **추가 후보(검토중)**: 월 세금비축 넛지(프리랜서 엔진에 이미 있음), 시즌 리마인더, 공제누락 경고.

## A-2. 엔진 상태 (코드 직접 확인 — 메모리보다 최신)
> 이전 메모리의 "노란우산 버그·근로소득공제 2000만 캡 없음·자녀공제 구버전"은 **모두 수정 완료됨**. 실제 병목은 엔진이 아니라 홈 UI.

| 영역 | 상태 |
|---|---|
| 직장인 (`employee_tax.dart`) | ✅ 4대보험·근로소득공제(2000만캡)·신용카드공제·의료/교육/기부·자녀(2025 25/30/40)·연금계좌·보험료·표준·인적추가·월세·고향사랑 — **거의 완비, year_end/annual_report에 연결** |
| 프리랜서 (`freelancer_tax.dart`) | ✅ 단순경비율·노란우산(600/500/400/200)·3.3% 환급예측·월세 |
| N잡러 (`combined_tax.dart`) | ✅ 근로+사업+연금+기타소득 합산, 세액공제 8종(보험·자녀·연금·월세·의료·교육·기부·혼인), 추가인적공제, 소득공제(주담대·고향사랑·4대보험), 중소기업취업자 감면 |
| 갭 (Tier3) | ✅ N잡 연금·기타소득 합산 완료, ✅ 금융소득 종합과세 완료, ✅ 검산 회귀테스트 45건 완료 |

## A-3. 홈 재설계 (현재 → 목표 7단)
**현재**(`_buildHomeContent` home_screen.dart:1082~): 유형선택→시즌배너→상단배너→소득·지출카드→유형별카드→그리드2카드→세로리스트→FAQ

**목표 7단**:
| 위치 | 내용 |
|---|---|
| 최상단 | 앱명+모드뱃지+설정 (유지) |
| 상단 | 유형 선택 + 프로필 요약(**예상연봉 입력 여기로**) |
| 중상단 | 소득·지출 현황 카드 (이번달, **읽기전용**) → 기록하기 진입 |
| 중단 | 유형별 핵심 액션 1개 (직장인=연말정산 / 프리랜서=종소세 / N잡러=합산경고) |
| 중하단 | 공제 가이드 넛지 (신용카드 문턱) |
| 하단 | 세무도구·달력·가계부 단일 리스트 |
| 최하단 | FAQ (유지) |
→ 연말정산 진입점을 **중단 + 하단 2곳**으로 축소.

### 설계 결정
- **입력 SSOT**: 소득·지출 모두 "기록하기→`expense_calendar_screen.dart`"에서만 입력. 홈 카드는 읽기전용. `monthly_income_records`/`expenses`가 진실원. `ledger_calendar_screen.dart`(범위드래그 없는 중복)는 제거 대상.
- **25% 임계값**: 연봉×25%(신용카드 문턱)만 유지. 월소득×25%는 "이번 달 카드 페이스"로 재해석(Tier2 선택). 지출목표×25%는 추가 안 함.
- **예상연봉**: 프로필 입력으로 (연말정산 진단에서 묻지 않음).

## A-4. 진행 상태
**이번 작업**
- [x] Phase 1 — project_context.md 정돈 + 메모리 정정
- [x] Phase 2 — 소득 동기화 수정 (홈 카드 소득 읽기전용, `_saveCurrentMonthIncome` 죽은코드 제거, ledger_calendar import 제거. 소득 SSOT=달력)
- [x] Phase 3 — 홈 전면 재배치: `_buildGridCards` 제거(연말정산·지출황금비율 중복 제거→진입점 2곳), 예상연봉 입력을 `EmployeeInputScreen`("내 월급/연봉 관리")에 추가+프로필 저장, 연봉 미설정 시 소득카드에 설정 유도 행. 죽은코드(`_goToExpenseEntry`·`_buildGradientIcon`·미사용 bgColor) 정리. analyze 에러 0.

**Tier 2 (후순위)**
- [x] 연금저축·IRP 절세 계산기 UI 연결 — `pension_calculator_screen.dart` 신규(`calculatePensionAccountTaxCredit` 연결), 세무도구 시트 "준비중" 해소
- [x] 월 권장 카드 페이스 1줄 표시 — 소득카드 신용카드 문턱 섹션에 `연봉×25%÷12` 권장 페이스 + 이번 달 진척 안내(`onPace`)
- [x] 자녀공제·인적공제 엔진 홈 노출 — `dependent_deduction_screen.dart` 신규(`calculateAdditionalPersonalDeduction`·`calculateChildTaxCredit`·기본/장애인공제, 프로필 저장→연말정산 진단 공유). 세무도구 시트 "부양가족 공제 확인" 연결
  - [x] 보험료 세액공제 — `insurance_premium_screen.dart` 신규 (`calculateInsurancePremiumTaxCredit`, 최대 27만원), 세무도구 시트 직장인/N잡러 연결

**Tier 3 (장기)**
- [x] 금융소득 종합과세 비교과세 — `tax_rates.dart` 상수 4개 추가, `combined_tax.dart`에 `FinancialIncomeTaxResult`·`calculateFinancialIncomeTax()` 추가, `financial_income_screen.dart` 신규. 세무도구 시트 공통 항목 연결
- [x] N잡 연금·기타소득 합산 — `employee_tax.dart`에 `calculatePensionIncomeDeduction/Amount`, `calculateOtherIncomeAmount`, 월세버그(7천→8천만) 수정. `combined_tax.dart` `calculateCombinedTax(pensionIncome, otherIncome)` 파라미터 추가, `CombinedTaxResult`에 `pensionIncomeAmount·otherIncomeAmount` 필드. `tax_simulator_screen.dart` N잡러 UI에 연금·기타소득 입력 추가
- [x] 검산 회귀테스트 45건 — `test/engine_regression_test.dart` (인적공제3, 신용카드2, 자녀3, 연금계좌8, 보험료2, 의료비7, 교육비1, 기부금3, 월세3, 연금소득공제4, 기타소득2, 금융소득2, 근로공제3, 세율2). 전원 통과.
- [x] 직장인 5월 종합소득세 확장 — DB v12(`wedding_year`, `children_count_8plus`, `newborn_count` 추가), `year_end_tax_screen.dart` wizard 개선(민감항목 안내박스, 본인교육비·장애인특수교육비 입력, 표준세액공제 13만 자동비교, 프로필 자동로드, directWizardMode 진입), 홈 세무도구 시트 직장인에 "5월 종합소득세 신고 준비" 항목 추가

**Tier 4 (2026-06-18 세션)**
- [x] N잡러 전체 공제 항목 연결 — `combined_tax.dart` 파라미터 확장 (추가인적공제·주담대·고향사랑·의료·교육·기부·혼인·중소기업), `tax_simulator_screen.dart` UI 확장 (새 입력필드 + 프로필 자동로드), N잡러 시뮬레이터 "소득공제 추가항목" 카드 신규 추가
- [x] 황금비율 카드 삭제 — `home_screen.dart` 중복 제거 (ExpenseTargetScreen 미사용)
- [x] 결제 넛지 시연 버튼 삭제 — `home_screen.dart` FloatingActionButton 및 `_simulatePayment()` 메서드 제거
- [x] 회귀테스트 재확인 — 45/45 전원 통과 (N잡러 추가 계산로직 포함)

**Tier 5 (2026-06-18 디자인 작업 — 진행중)**
- [x] 디자인 시스템 v4.0 "Architectural Blueprint" — `app_theme.dart` 전면 재작성. google_fonts 추가(DM Serif Display 제목 + Noto Serif KR 한글대체 + DM Sans 본문), 라이트 #F8F7F5 / 다크 #0D0D0D, 카드·그림자 제거→1px 헤어라인, 거의 직각(radius 4~6 clamp), 텍스트 위계·가독성 강화. `getCardDecoration`/`getAccentCardDecoration` 시그니처 유지(하위호환). 신규 헬퍼: `serif/sans/label/hairline/ink/inkSecondary/inkTertiary/line/accentColor/blueprintBadge`.
- [x] 홈 화면 완전 에디토리얼 전환 — 브랜드 세리프, 타입선택기=텍스트탭(하단라인), 상단배너=세리프헤드+도면S박스, **월 소득+지출 통합 섹션**(52px 세리프 금액, 1px 선 구분), 세무도구=번호 인덱스(01/02/03)+도면배지, 전체보기·FAQ 에디토리얼, 하단네비=기하학 아이콘(□↗↘△○). 황금비율·결제넛지·수동입력뱃지·소득/달력/가계부 중복행 제거 완료.
- [ ] **남은 작업: 세부 화면 전파** — year_end_tax/tax_simulator/tax_annual_report/financial_income/pension/dependent/insurance/profile_input 등 각 화면의 인라인 TextStyle을 `AppTheme.serif/sans/label`로, 카드를 헤어라인 구조로 교체. 온보딩 01/05 스텝 표시. (테마 토큰은 이미 전 화면 전파되어 색/폰트 기본은 적용됨)

**Tier 6 (2026-06-19 홈 디자인 그릴 라운드)**
- [x] 소득 SSOT 정리 — `income_entries`가 단일 진실원(이미 `_recalcMonthlyIncome`로 `monthly_income_records`에 브리지됨 확인). 중복·우회 화면 `income_calendar_screen.dart`·`ledger_calendar_screen.dart` 삭제(둘 다 orphan, monthly_income_records 직접 기록으로 가계부와 불일치 유발).
- [x] 하단 탭 4개 연결 — `_onNavTap`: 소득→`ExpenseCalendarScreen(initialFocus:'income')`, 지출→`'expense'`, 세무→도구 시트, 내정보→프로필. 복귀 시 `_loadDataFromDB` 재동기화. (기존: index만 바꾸고 body 고정 = 죽은 탭)
- [x] 월급여일(pay_day) UI — 스키마 이미 존재(v15). 소득 섹션에 직장인·N잡 급여일 피커(1~31 그리드), profile save/load 연결.
- [x] 바텀시트 블루프린트 재작성 — `_showTaxToolsSheet`·`_showSettingsBottomSheet` 그라데이션 ShaderMask·radius24 제거→AppTheme 토큰·헤어라인. 도구 시트 중복 진입점 제거(홈 인덱스에 있는 연말정산 제외), 프리랜서 "준비중" 모순 제거. `_toolItem`/`HomeTossButton` 죽은코드 제거.
- [x] 가독성/위계 — `lightInkTertiary` #908D86→#6B6862(대비 ~4.6:1 AA). 수입(44px)/지출(34px sub) 금액 위계 분리. 헤더 아이콘 토큰화.
- [x] 계절 배너 — `_buildTopBanner` 월 분기(1~3 연말정산/4~5 종소세/평시 절세준비), 죽은 알림 종 제거.
- [x] 알림 3종 + iOS — `notification_helper` iOS `DarwinInitializationSettings`·`scheduleAtDate`·`cancelAll`. 신규 `core/notifications/reminder_scheduler.dart`(세금시즌·월간 급여일 넛지·공제문턱 즉시). 설정 시트 알림 토글(세션 내). 회귀테스트 45/45 유지, build web 통과.
- [ ] **알림 on/off 영구 저장**(현재 세션 내 메모리) — 후속. `monthly_income_records` 테이블 자체 드롭도 후속.

**현재 앱 완성도: 90%**
- 엔진: 직장인·프리랜서·N잡러 모두 동일한 공제 항목 반영 완료 (98%)
- UI: 모든 세무도구 화면 구현 및 연결 완료 (90%)
- 데이터: 프로필 v13 전체 필드 save/load 완성 (95%)
- 배포: 메타데이터·코드정리·실기기테스트·세법유지보수·알림시스템 남음 (5%)

## A-5. 다음 단계 (Tier 5 이후)

**진행 우선순위**
1. **유형별 카드 배치 & 기능 검토** — 홈 화면 UX 최적화 (직장인/N잡러/프리랜서 진입 명확화)
2. **디자인 개선** — 색상·타이포·컴포넌트 일관성 + 어두운 테마 지원
3. **배포 준비** — 순서: 메타데이터(아이콘·스플래시) → 세법유지보수 → 실기기테스트 → 알림시스템 → 코드정리

**남은 작업 상세**
- **홈 재설계**: 시즌 배너 조건부 표시 → 고정 카드로 변경, 연말정산/종소세 진입점 단일화
- **N잡러 입력폼**: 근로소득+프리랜서소득 동시 입력 가능하도록 (현재 세무도구 시트에만 있음)
- **메타데이터**: Android `build.gradle` 서명 설정, iOS `Info.plist`, 스토어 메타데이터 작성
- **세법유지보수**: 2027년 귀속 세율 변경 시 `tax_rates.dart` 업데이트 전략
- **알림시스템**: 연말정산/종소세 시즌 리마인더 구현 (`notification_helper.dart` 이미 기본 골격 있음)
- **코드정리**: `ledger_calendar_screen.dart` 제거 (미사용 중복), 기타 dead code 정리

## A-6. 정정 메모
- DB 버전은 **v13**(`db_helper.dart` version: 13, 2026-06-18 `is_sme_employee`, `sme_start_year` 추가).
- 소득 테이블은 **`monthly_income_records`** (SSOT).
- expenses category: 신용카드/체크카드/현금 (구버전 호환 코드 있음).
- **엔진 최종 상태**: 
  - 직장인: 모든 공제 항목 완비 + 연말정산 wizard + 5월 종소세 준비 (directWizardMode)
  - 프리랜서: 단순경비율 + 3.3% 환급 + 월세 세액공제
  - N잡러: 근로+사업+연금+기타소득 합산 + 모든 세액공제 + 중소기업 감면
