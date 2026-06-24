# 토스 스타일 전면 개편 계획 (다크모드 + 온보딩 UX)

회원님께서 토스 앱에서 가장 부러워하셨던 두 가지 핵심, **'색상 단차로 만든 완벽한 다크모드'**와 **'한 화면에 질문 하나씩 던지는 온보딩 UX(Toss Form)'**를 세끌 앱에 완벽하게 이식하겠습니다.

---

## 1. 다크모드 개편 (이전 제안 유지)
토스의 디자인 룰에 맞춰 **[A안] 완벽한 토스 클론** 모드로 진행하겠습니다. (그림자 완전 제거, `1C1C1E` 카드 색상 단차, 토스 블루/그레이 포인트 사용, 24px 대폭 둥근 모서리)

---

## 2. 입력 화면(UX) 개편 선택지 (A/B/C안)
기존에 한 화면에 여러 입력칸이 나열되어 있던 폼(예: 프로필 입력, 연말정산 정보 입력 등)을 토스처럼 개편합니다. 어떤 방식이 가장 마음에 드시나요?

### **[A안] 완벽한 토스 폼 (Toss Form, 강력 추천)**
회원님이 말씀하신 바로 그 방식입니다.
- **1화면 1질문**: "현재 연봉은 얼마인가요?", "부양가족이 있나요?" 처럼 한 화면에 아주 크고 명확한 질문 하나만 던집니다.
- **자동 포커스 & 하단 고정 버튼**: 화면이 넘어가면 자동으로 키보드가 올라오고, 키보드 바로 위에 꽉 찬 '다음' 버튼이 따라다닙니다.
- **부드러운 슬라이드**: 입력 후 '다음'을 누르면 다음 질문으로 스르륵 부드럽게 화면이 전환됩니다. (`PageView` 활용)

### **[B안] 연속 바텀 시트형 (Bottom Sheet Flow)**
- 화면 이동 없이, 하단에서 바텀 시트가 올라와 질문을 던집니다. 하나를 입력하면 그 시트 안에서 내용이 바뀌며 다음 질문을 묻습니다. (최근 카카오뱅크 등에서 자주 쓰는 방식)

### **[C안] 스크롤 자동 펼침형 (Accordion Form)**
- 한 화면에 있긴 하지만, 처음엔 첫 번째 질문만 보입니다. 입력을 완료하면 그 아래로 다음 질문이 스르륵 마법처럼 펼쳐지며 자동 스크롤됩니다.

---

## 🛠️ 변경될 내용 (Diff Preview)
A안 선택 시 `profile_input_screen.dart`의 구조가 다음과 같이 전면 교체됩니다.

```diff
- // 기존: 단일 Column에 TextField 여러 개 나열
- Column(
-   children: [
-     TextField(decoration: InputDecoration(labelText: '연봉')),
-     TextField(decoration: InputDecoration(labelText: '부양가족')),
-   ]
- )

+ // 변경: PageView로 한 화면에 하나씩 노출
+ PageView(
+   controller: _pageController,
+   physics: NeverScrollableScrollPhysics(), // 스와이프 금지
+   children: [
+     _buildSingleQuestionPage(question: '현재 연봉이\n얼마인가요?', ...),
+     _buildSingleQuestionPage(question: '부양가족이\n있으신가요?', ...),
+   ]
+ )
+ // 하단 키보드 위 고정 버튼
+ KeyboardSafeArea(
+   child: FullWidthButton(text: '다음', onPressed: _nextPage)
+ )
```

## User Review Required
> [!IMPORTANT]  
> 회원님, "토스 다크모드 A안"과 함께 **온보딩 UX 방식(A, B, C안)** 중 어떤 것을 적용할지 말씀해 주세요. (A안 '완벽한 토스 폼'을 가장 추천합니다.)
> 승인이 떨어지는 즉시 **디자인과 UX 모두 토스처럼 부드럽고 고급스럽게 전면 개조**하겠습니다!