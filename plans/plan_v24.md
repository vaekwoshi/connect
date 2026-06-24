# 토스 스타일 다크모드 전면 개편 계획 (Toss Style Revamp)

회원님께서 첨부해주신 토스 다크모드는 **'그림자'가 아닌 '색상의 단차(Elevation)'와 '여백', 그리고 '둥근 모서리(Border Radius)'로 깊이감을 완성**하는 완벽한 프리미엄 디자인의 정석입니다. 

기존의 네온 컬러와 그림자를 모두 걷어내고, 첨부해주신 스크린샷과 100% 동일한 결의 프리미엄 디자인으로 전면 엎겠습니다.

## 💡 디자인 개편 선택지 (A/B/C안)

어떤 방향으로 엎을지 아래 옵션 중 하나를 선택해 주시면 즉시 코드 치환에 돌입하겠습니다.

### **[A안] 완벽한 토스 클론 (추천)**
스크린샷의 토스 디자인 시스템을 그대로 이식하여 가장 깔끔하고 익숙한 사용성을 제공합니다.
- **배경색**: 완전한 다크 (`#101010` 또는 `#0B0D0F`)
- **카드색**: 배경보다 살짝 뜬 다크 그레이 (`#1C1C1E`), 모서리 곡률 **24px** (대폭 둥글게)
- **그림자**: **완전 제거** (다크모드에서는 그림자가 지저분해 보이므로 색상 단차로만 분리)
- **포인트 컬러**: 토스 블루 (`#3182F6`), 보조 텍스트는 토스 그레이 (`#8B95A1`)
- **버튼**: 카드 내부 버튼은 둥근 알약 형태의 다크 톤 (`#333D4B` 등)

### **[B안] 세끌 프리미엄 다크 (독자적 고급화)**
토스의 깔끔한 레이아웃을 가져가되, 세끌만의 고유한 브랜드 컬러(네이비/청록)를 은은하게 섞습니다.
- **배경/카드**: 미세하게 네이비가 섞인 딥 다크 (`#0B0F19` / `#1A1F2C`)
- **그림자**: 은은한 글로우(Glow) 효과 유지
- **포인트 컬러**: 기존 청록색(Cyan-Blue) 톤 유지

### **[C안] 완전 블랙 (OLED 최적화)**
- **배경색**: 완전한 순수 블랙 (`#000000`) - 배터리 절약 및 극단적 대비
- **카드색**: 토스 스타일 회색 카드 (`#1C1C1E`)
- **포인트 컬러**: 화이트 & 토스 블루 혼합

---

## 🛠️ 변경될 내용 (Diff Preview)
A안 선택 시 `app_theme.dart`와 카드 UI가 다음과 같이 전면 교체됩니다.

```diff
- static const Color darkBackground = Color(0xFF0C0F13);
- static const Color darkCard = Color(0xFF151D26);
+ static const Color darkBackground = Color(0xFF101010); // 토스 배경
+ static const Color darkCard = Color(0xFF1C1C1E);       // 토스 카드
+ static const Color tossBlue = Color(0xFF3182F6);       // 토스 블루
+ static const Color tossGray = Color(0xFF8B95A1);       // 보조 텍스트 그레이

- static BoxDecoration getCardDecoration(...) {
-   boxShadow: [ BoxShadow(color: ..., blurRadius: 16) ]
- }
+ static BoxDecoration getCardDecoration(...) {
+   borderRadius: BorderRadius.circular(24.0), // 대폭 둥글게
+   boxShadow: [], // 그림자 완전 제거
+   // 색상 단차만으로 깊이감 표현
+ }
```

## User Review Required
> [!IMPORTANT]  
> 회원님, **A, B, C안 중 원하시는 방향을 하나 골라주세요.** (A안을 가장 추천합니다.)  
> 선택해 주시면 `app_theme.dart`부터 홈 화면(`home_screen.dart`)의 버튼 형태, 글자 크기, 여백까지 **토스 앱처럼 완벽하게 엎어서** 바로 에뮬레이터에 띄워드리겠습니다!