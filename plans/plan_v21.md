# 홈 화면 5단 레이아웃 전체 청사진 v5.0

> [!IMPORTANT]
> **이 문서는 특허 명세서(`patent_draft_official.md`)와 1:1 대응하는 구현 로드맵입니다.**
> 작업 시 반드시 명세서의 청구항 번호와 도면 번호를 참조하여, 코드가 청구항을 뒷받침하는지 확인하세요.

> [!CAUTION]
> **절대 금지 사항 (사용자 룰)**
> - 파일 전체 덮어쓰기(`write_to_file`) 금지 → `replace_file_content`로 정밀 수정만
> - 바텀 시트 사용 금지 → 반드시 **새 스크린(`Navigator.push`)** 사용
> - 사용자 승인 없이 UI/텍스트 임의 변경 금지
> - 청구항 개수/권리 범위를 자의적으로 축소/통합/삭제 금지
> - 애매한 부분은 반드시 A안/B안/C안 선택지를 먼저 제시하고 승인 후 작업

---

## 명세서 ↔ 코드 매핑표 (핵심 참조)

| 명세서 구성요소 | 부호 | 대응 코드 파일 | 상태 |
|---|---|---|---|
| 사용자 세무 프로필 설정부 | 113 | `tax_persona_question_screen.dart`, `profile_input_screen.dart` | ✅ |
| 제1모드 오프라인 파싱부 (OCR/수기) | 111 | `employee_input_screen.dart`, `freelancer_input_screen.dart` (수기만) | ⚠️ OCR 미구현 |
| 제2모드 외부 금융망 연동부 | 112 | 미구현 (명세서상 선택적) | 📋 후순위 |
| 온디바이스 보안 저장부 | 120 | `db_helper.dart` + `crypto_helper.dart` | ✅ |
| 데이터 영구 파기 (124단계) | 124 | `destroyAllData()` in `db_helper.dart` | ✅ |
| 온디바이스 연산 엔진 | 200 | `core/tax_engine/` 폴더 전체 | ✅ |
| 제1 로컬 연산 모듈 (근로소득) | 210 | `employee_tax.dart` | ✅ |
| 제2 로컬 연산 모듈 (사업소득) | 220 | `freelancer_tax.dart` | ✅ |
| 제3 로컬 연산 모듈 (복합소득) | 230 | `combined_tax.dart` | ✅ |
| 세무 요율 로컬 탑재 | - | `tax_rates.dart` | ✅ |
| 4대 보험 연산 | - | `insurance_engine.dart` | ✅ (보너스) |
| 다중 알림 기반 가이드부 | 300 | `home_screen.dart` `_buildBannerCard()` | ⚠️ 앱 내 위젯만 |
| 상단 동적 넛지 알림부 | 311 | `_buildBannerCard()` | ⚠️ 로컬 푸시 미구현 |
| 중단 맞춤형 데이터 수집부 | 312 | `_buildIncomeCard()`, `_buildSpendingCard()` | ✅ |
| 하단 데이터 시각화부 | 313 | 프로그레스 바, 넛지 텍스트 | ⚠️ 그래프 미구현 |
| 사용자 디스플레이 | 310 | `home_screen.dart` 전체 | ✅ |

---

## 작업 우선순위 (반드시 이 순서대로)

> [!WARNING]
> **P0은 특허 청구항을 직접 뒷받침하는 기능입니다. 이것들이 없으면 특허 실시 가능 요건 입증이 불가합니다.**
> P1은 사용자 경험에 필수이지만 특허와는 간접 관련입니다.
> P2는 있으면 좋지만 당장 급하지 않습니다.

| 순위 | 작업 | 청구항 | 현재 상태 | 설명 |
|---|---|---|---|---|
| **P0-0** | 토스 스타일 UI 전면 개편 | 310 | ✅ 완료 | `home_screen.dart`, `profile_input_screen.dart`, `app_theme.dart` 다크/라이트모드 완벽 연동 및 배색 오류 수정 |
| **P0-1** | 도구 카드 → 시뮬레이터 스크린 연결 | 7,8,9,12,13,14 | ✅ 완료 | `home_screen.dart`에서 `Navigator.push`로 연결 완료 |
| **P0-2** | 로컬 푸시 알림 (능동적 넛지) | 10,11 | ✅ 완료 | `notification_helper.dart` 구현 및 적용 완료 |
| **P0-3** | 1:1 맞춤 세금 신고서 양식 생성 | 11 (방법 청구항) | ✅ 완료 | `tax_report_form_screen.dart` 구현 완료 |
| **P1-1** | 지출 목표 카드 리팩토링 | - | ✅ 완료 | `expense_target_screen.dart` 분리 및 리팩토링 완료 |
| **P1-2** | 경비 관리 카드 (프리랜서 중단) | - | ✅ 완료 | 홈 화면 내 `_buildFreelancerExpenseCard` 구현 완료 |
| **P1-3** | 간편장부 도구 카드 연결 | - | ✅ 연결 완료 | `freelancer_book_screen.dart` 정상 진입 가능 |
| **P2-1** | OCR 증빙 인식 | 3 (청구항) | 📋 후순위 | 카메라로 영수증 촬영 → 텍스트 파싱. `google_mlkit_text_recognition` 등 |
| **P2-2** | 소비 누적 그래프 (하단 시각화) | - | 📋 후순위 | 차트 라이브러리 추가 시 사용자 승인 필수 |
| **P2-3** | 플로팅 팝업 넛지 | 청구항 10 | 📋 후순위 | 결제 시점에 화면 위에 뜨는 팝업. 외부 금융망 연동(112) 이후에 의미 있음 |

---

## 직장인

| 단 | 카드명 | 핵심 내용 | 상태 |
|---|---|---|---|
| **최상단** | 광고/배너/알림 | **[유형/주기별 노출 로직]**<br>1. X 클릭 시 광고 72시간, 배너/알림 24시간 숨김<br>2. 사용자가 정보 입력 완료 시 168시간(7일) 숨김 후 '수정 알림' 카드로 변환 표시 | ✅ |
| **상단** | 월 급여 카드 | 세전 월급여 입력 / 하위: **[소득 기록 모두보기 (달력 뷰)]** | ✅ |
| **중단** | 지출 목표 카드 | **[리팩 필요]** 이번 달 목표 지출액 설정 + 달성률 요약만 표시. 카드 클릭 시 새 스크린에서 신용/체크/현금 세부 입력 및 황금비율 분석 | ⚠️ P1-1 |
| **중하단** | 도구 카드 | **[연말정산]** → `year_end_tax_screen.dart`, **[종합소득세]** → `tax_simulator_screen.dart` | 🔴 P0-1 |
| **최하단** | FAQ 카드 | 직장인 자주 묻는 질문 (아코디언 드롭다운 적용) | ✅ |

**직장인 도구 카드 상세**:
| 도구 | 설명 | 상태 |
|---|---|---|
| 연말정산 | `year_end_tax_screen.dart` → 당해 연도 시뮬레이션 + 과거 기록부 | ✅ P0-1 연결 완료 |
| 종합소득세 | `tax_simulator_screen.dart` → 당해 연도 시뮬레이션 + 과거 기록부 | ✅ P0-1 연결 완료 |

---

## 프리랜서

| 단 | 카드명 | 핵심 내용 | 상태 |
|---|---|---|---|
| **최상단** | 광고/배너/알림 | 직장인과 동일한 노출 로직 | ✅ |
| **상단** | 수입 카드 | 누적 수입(3.3%), 업종코드, 노란우산 / 하위: **[소득 기록 모두보기 (달력 뷰)]** | ✅ |
| **중단** | 경비 관리 카드 | 필요경비 증빙 현황, 경비율 구간별 절세 넛지 | 🔴 P1-2 |
| **중하단** | 도구 카드 | **[종합소득세]**, **[간편장부 작성]**, **[적격증빙 체크리스트]** | 🔴 P0-1, P1-3 |
| **최하단** | FAQ 카드 | 프리랜서 자주 묻는 질문 (아코디언 드롭다운 적용) | ✅ |

**프리랜서 도구 카드 상세**:
| 도구 | 설명 | 상태 |
|---|---|---|
| 종합소득세 | 예상 환급액/납부액 시뮬레이터 + 기납부 세액 확인 | ✅ P0-1 연결 완료 |
| 간편장부 작성 | `freelancer_book_screen.dart` → 지출 내역으로 자동 작성 | ✅ P1-3 연결 완료 |

---

## N잡러

| 단 | 카드명 | 핵심 내용 | 상태 |
|---|---|---|---|
| **최상단** | 광고/배너/알림 | 직장인과 동일한 노출 로직 | ✅ |
| **상단** | 소득 합산 카드 | 월급여 + 부업 수입(3.3%) 병렬 / 하위: **[소득 기록 모두보기 (달력 뷰)]** | ✅ |
| **중단** | 지출/경비 분리 카드 | 직장분: 25% 문턱 / 부업분: 필요경비 현황 | ✅(직장) / 🔴(부업) P1-2 |
| **중하단** | 도구 카드 | **[연말정산]**, **[종합소득세]**, **[부업 장부]** | 🔴 P0-1 |
| **최하단** | FAQ 카드 | N잡러 자주 묻는 질문 (아코디언 드롭다운 적용) | ✅ |

**N잡러 도구 카드 상세**:
| 도구 | 설명 | 상태 |
|---|---|---|
| 연말정산 | 직장 근로소득 기준 연말정산 시뮬레이션 + 과거 기록부 | ✅ P0-1 연결 완료 |
| 종합소득세 | 근로+사업 합산 과세 및 건보료 시뮬레이션 + 과거 기록부 | ✅ P0-1 연결 완료 |

---

## 코드 아키텍처 안내 (신규 작업자용)

### 폴더 구조
```
lib/
├── main.dart                      # 앱 엔트리포인트
├── core/
│   ├── data/
│   │   ├── db_helper.dart         # ⭐ DB 서비스 (Sqflite + InMemory)
│   │   └── expense_item.dart      # 지출 데이터 모델
│   ├── security/
│   │   └── crypto_helper.dart     # ⭐ AES 암호화/복호화
│   └── tax_engine/                # ⭐ 온디바이스 연산 엔진(200) 핵심
│       ├── employee_tax.dart      # 제1 로컬 연산 모듈(210)
│       ├── freelancer_tax.dart    # 제2 로컬 연산 모듈(220)
│       ├── combined_tax.dart      # 제3 로컬 연산 모듈(230)
│       ├── insurance_engine.dart  # 4대보험 연산
│       └── tax_rates.dart         # 세율표 (로컬 탑재)
└── ui/
    └── screens/
        ├── home_screen.dart            # ⭐ 메인 홈 (5단 카드 레이아웃)
        ├── tax_persona_question_screen.dart  # 유형 판별 질문(113)
        ├── profile_input_screen.dart   # 세무 프로필 상세 입력
        ├── employee_input_screen.dart  # 직장인 월급 입력
        ├── freelancer_input_screen.dart # 프리랜서 수입 입력
        ├── income_calendar_screen.dart # 소득 달력 뷰
        ├── tax_simulator_screen.dart   # 종합소득세 시뮬레이터
        ├── year_end_tax_screen.dart    # 연말정산 시뮬레이터
        ├── freelancer_book_screen.dart # 간편장부
        ├── tax_record_list_screen.dart # 과거 세무 기록부
        ├── secret_tax_guide_screen.dart # 절세 가이드
        ├── more_screen.dart           # 더보기/설정
        └── onboarding_screen.dart     # 온보딩
```

### 핵심 상태 변수 (`home_screen.dart`)
- `_userType`: `'직장인'` | `'프리랜서'` | `'N잡러'` → 모든 카드 조건부 렌더링의 기준
- `_isEmployee` / `_isFreelancer`: 위 유형에서 파생된 getter
- `_currentBannerIndex`: 최상단 배너 롤링 인덱스
- `_bannerStates`: `Map<String, int>` → 각 배너 ID별 숨김 만료 시간(epoch ms)
- `_isProfileCompleted`: 유형 판별 완료 여부 (168h 변환 카드 판단에 사용)

### DB 스키마 (v4)
- `user_profile`: 사용자 세무 프로필 (단일 row)
- `expenses`: 지출 내역 (암호화 저장)
- `tax_records`: 연도별 세무 기록
- `banner_states`: 배너 숨김 상태 (`banner_id TEXT PK`, `hide_until_epoch INT`)

### 주의사항
- `SqfliteDatabaseHelper` 수정 시 반드시 `InMemoryDatabaseHelper`에도 동일 메서드 구현 (빌드 에러 방지)
- DB 버전 올릴 때 `onUpgrade`에 마이그레이션 추가 필수
- `dbService`는 전역 싱글턴 → 테스트 시 `InMemoryDatabaseHelper()`로 교체

---

## 빌드 & 배포 명령어
```powershell
# 빌드 + 에뮬레이터 설치 + 자동 실행 (한 줄)
flutter build apk --debug ; & "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk ; & "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" -s emulator-5554 shell monkey -p com.example.secul -c android.intent.category.LAUNCHER 1
```

---

## 변경 이력
| 버전 | 날짜 | 내용 |
|---|---|---|
| v4.2 | 2026-06-16 | 배너/알림 카드 통폐합, 도구 카드 2탭 구조 |
| v5.0 | 2026-06-16 | 명세서 대조 평가 추가, 우선순위 정리, 코드 아키텍처 가이드 추가, P0/P1/P2 분류 |
| v5.1 | 2026-06-17 | 토스 스타일 다크모드/라이트모드 UI 전면 개편 (profile, home), 앱 테마 시스템 연동 완료, 빌드 오류 수정 |
