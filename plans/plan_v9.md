# 스토어 배포 전 로컬 DB 연동 및 물리적 파기 기능 결합 최종 완료 계획

특허 우선일(Priority Date) 확보(수수료 13,800원 납부 및 접수 완료)에 따라 법적 리스크 없이 6월 말 앱 배포 타임라인에 안착하기 위해, "세끌 온디바이스 세무 가이드 앱"의 화면 UI와 암호화 DB 간의 실질적 데이터 바인딩 및 물리적 파기(Shredding) 버튼 연동을 완수합니다.

---

## 🔍 현황 및 문제점 분석

*   **UI-데이터 분리 상태:** 암호화 데이터베이스 저장소(`DatabaseService`) 모듈은 구현 및 테스트가 완료되었으나, 홈 화면(`HomeScreen`), 절세 프로필 입력 화면(`ProfileInputScreen`), 그리고 개별 소득/지출 입력 다이얼로그에서 이 저장소를 전혀 호출하지 않고 있어 앱 종료 시 데이터가 휘발됩니다.
*   **물리적 파기 기능 UI 누락:** 특허 청구범위의 핵심인 "복구 불가능한 영구 파기(Shredding)" 알고리즘이 DB단에는 구현되었지만, 실제 사용자가 이를 실행할 수 있는 UI 진입로가 마련되지 않았습니다.

---

## 🛠️ Proposed Changes (제안안)

### 1. 로컬 DB 서비스 글로벌 인스턴스 노출 및 초기화
*   [db_helper.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/core/data/db_helper.dart)에 글로벌 싱글톤 서비스 객체 `dbService`를 정의하여 UI 화면에서 손쉽게 가져다 쓸 수 있도록 합니다.
*   [main.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/main.dart)의 `main()` 함수에서 `WidgetsFlutterBinding.ensureInitialized()`를 보장하고 `dbService.initDatabase()`를 사전에 대기 실행합니다.

### 2. 절세 프로필 화면 및 소득 입력 화면 DB 연동
*   [profile_input_screen.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/ui/screens/profile_input_screen.dart):
    *   `initState()` 실행 시 DB에서 프로필 데이터를 로드하여 입력 필드 초기값 세팅.
    *   "프로필 저장하기" 탭 시 `dbService.saveProfile()`을 비동기 수행하여 암호화 데이터베이스에 영구 반영.
*   [home_screen.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/ui/screens/home_screen.dart):
    *   `initState()`에서 `dbService.getProfile()` 및 `dbService.getExpenses()`를 호출하여 사용자의 세무 설정값을 복구하고 텍스트 컨트롤러들에 할당.
    *   직장인 급여(EmployeeInputScreen) 및 프리랜서 수입(FreelancerInputScreen) 정보 반환 시 `dbService.saveProfile()`을 호출하여 DB 상태 최신화.
    *   지출 입력 다이얼로그(`_showActualSpendingDialog`) 확인 시, 입력값을 `ExpenseItem`으로 전환하여 `dbService.insertExpense()`로 암호화 저장.
    *   개발 편의를 위해 꺼두었던 '프로필 완성 여부 블러 락(Blur Lock)'을 실제 DB 프로필 존재 상태(`_isProfileCompleted`)에 따라 동적으로 잠금/해제되도록 복구.

### 3. 특허 핵심 '개인 정보 영구 파기(Shredding)' UI 결합
*   [home_screen.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/ui/screens/home_screen.dart)의 상단 `AppBar` 영역 우측에 데이터 영구 소거 설정 기어 아이콘(설정 버튼)을 추가합니다.
*   아이콘 클릭 시 바텀 시트 또는 다이얼로그를 통해 **"⚠️ 개인 세무 데이터 영구 파기"** 액션을 제공합니다.
*   파기 클릭 시:
    1.  "정말 모든 데이터를 복구 불가능하게 파기하시겠습니까? 특허 기술(3단계 물리 소거)을 사용해 플래시 메모리에서 영구 삭제하므로 절대 복구할 수 없습니다." 경고 팝업 안내.
    2.  확인 클릭 시 `dbService.destroyAllData()` 실행.
    3.  완료 후 메모리 상의 세무 데이터 컨트롤러/변수를 일괄 클리어(`setState`)하고 화면을 온보딩/프로필 미작성(블러 락 활성화) 상태로 되돌립니다.

---

## 📋 Verification Plan (검증 계획)

### Automated Tests
*   `flutter test test/database_test.dart`를 실행하여 암호화 및 파기 로직의 회귀 여부를 점검합니다.
*   `flutter test test/widget_test.dart` 또는 수동 에뮬레이터 검증을 통해 컴파일 에러가 없는지 체크합니다.

### Manual Verification
*   실기 에뮬레이터에서 앱을 구동합니다.
*   프로필을 작성하고 앱을 완전히 종료(Kill Process)한 뒤 재접속하여 데이터가 암호화되어 안전하게 유지되는지 확인합니다.
*   '개인 정보 영구 파기' 버튼을 실행하여 데이터가 실제로 모두 비워지고 블러 락(초기화) 상태로 완벽히 리셋되는지 검증합니다.
