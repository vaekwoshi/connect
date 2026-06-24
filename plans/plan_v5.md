# [구현 계획] 1단계: 세법 엔진 빌드 컴파일 에러 수정 및 테스트 통과

세법 연산 엔진을 정밀 검증하고 테스트를 구동하기 위한 사전 작업으로, 현재 빌드 과정에서 발생하는 3가지 컴파일 에러를 정밀 타격(Surgical Change)하여 해결합니다.

---

## 제안하는 변경 사항

### 1. 홈 화면 컨트롤러 누락 수정

#### [MODIFY] [home_screen.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/ui/screens/home_screen.dart)

*   `_monthlyRentController` 선언부를 추가하여 62라인의 리스너 등록 시 에러가 나지 않도록 합니다.
*   `dispose()` 생명주기 메서드에 리소스 해제 코드를 추가하여 메모리 누수를 방지합니다.

```dart
// 선언부 추가 (Line 32 부근)
final TextEditingController _debitCashController = TextEditingController();
+ final TextEditingController _monthlyRentController = TextEditingController();

// 해제부 추가 (Line 85 부근)
_debitCashController.dispose();
+ _monthlyRentController.dispose();
```

---

### 2. 시뮬레이션 테스트 속성명 불일치 수정

#### [MODIFY] [tax_engine_simulation_test.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/test/tax_engine_simulation_test.dart)

*   `RentRefundResult`에 정의되어 있지 않은 `totalRefund` 속성을 공식 속성명인 `expectedRefund`로 교정합니다.

```dart
// Line 29 수정
- expect(result.totalRefund, lessThanOrEqualTo(decidedTax * 1.1 + 1.0));
+ expect(result.expectedRefund, lessThanOrEqualTo(decidedTax * 1.1 + 1.0));
```

---

### 3. 위젯 테스트 메인 클래스명 수정

#### [MODIFY] [widget_test.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/test/widget_test.dart)

*   존재하지 않는 `MyApp` 생성자를 실제 앱 메인 진입점인 `SeculApp`으로 교체하고, 누락된 `package:secul/main.dart` 임포트를 추가합니다.

```dart
// import 추가 및 MyApp -> SeculApp 변경
+ import 'package:secul/main.dart';
...
- await tester.pumpWidget(const MyApp());
+ await tester.pumpWidget(const SeculApp());
```

---

## 검증 계획

### 자동화 테스트
*   `flutter test` 명령어를 실행하여 빌드가 정상적으로 완료되는지 확인하고, 작성된 모든 단위 테스트가 통과하는지 검증합니다.
