# [구현 계획] 3단계: UI/UX 정교화 및 알림 넛지 인터랙션 구현

특허 **【도 8: 다중 알림 기반 동적 3단 UI 레이아웃 렌더링 화면 블록도】**의 핵심 요구사항을 완벽히 만족하기 위해, 홈 화면의 지출 현황 카드 내부에 **"소비 넛지 신호등 프로그레스 바(Nudge Progress Bar)"**를 새롭게 설계 및 탑재합니다.

---

## 🔍 현황 및 문제점 분석

*   **현 상태:** `home_screen.dart`의 `_buildExpenseCard()` 내부에는 현재 수치 텍스트와 줄 글 넛지 가이드만 존재하며, **소비 누적 그래프(시각화 레이어)가 누락**되어 있습니다.
*   **해결책:** 총급여 대비 문턱값(25%) 위치를 마커로 표시하고, 현재 소비 합산액의 위치를 나타내는 선형 프로그레스 바를 추가합니다. 
    *   **문턱 미달 시:** 노란색 게이지 + 신용카드 권장 넛지
    *   **문턱 돌파 시:** 초록색 게이지 + 체크카드/현금 권장 넛지

---

## 🛠️ 제안하는 변경 사항

### 1. 홈 화면 내 프로그레스 바 탑재 및 디자인 시스템 적용

#### [MODIFY] [home_screen.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/세끌/lib/ui/screens/home_screen.dart)

*   `_buildExpenseCard()` 내의 텍스트 영역과 하단 가이드 카드 사이에 **`_buildNudgeProgressBar()`** 위젯을 추가합니다.
*   디자인 에스테틱스(Wow factor)를 충족하는 어두운 회색 트랙, 은은한 네온 글로우 효과(Shadow)를 갖춘 게이지바, 그리고 문턱(25%) 위치를 표시하는 점선 버티컬 가이드를 배치합니다.

```dart
// _buildExpenseCard() 내에 추가될 신규 그래프 컴포넌트 렌더링 함수
Widget _buildNudgeProgressBar({
  required double totalSpending,
  required double threshold,
  required bool isOverThreshold,
}) {
  // 1. 달성 비율 계산 (최대 100%)
  double ratio = threshold > 0 ? (totalSpending / threshold) : 0.0;
  if (ratio > 1.0) ratio = 1.0;

  // 2. 색상 정의 (미달: 네온 노랑/주황, 돌파: 네온 민트/초록)
  final Color gaugeColor = isOverThreshold ? const Color(0xFF3BFFD1) : const Color(0xFFFFB800);
  final Color shadowColor = gaugeColor.withOpacity(0.4);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      // 게이지 트랙 및 바
      Stack(
        children: [
          // 회색 배경 트랙
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF2A323D),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          // 채워지는 게이지 바
          FractionallySizedBox(
            widthFactor: ratio,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: gaugeColor,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
          ),
          // 문턱 가이드 마커 (25% 지점 - 본 발명에서 청구한 시각적 문턱 임계선)
          // 25% 지점은 전체 용량(예: 연봉 25%)의 100%이므로, 이 게이지는 문턱값까지를 100%로 시각화합니다.
          // 따라서 마커는 게이지의 우측 끝(100% 지점)에 '공제 문턱선' 점선 또는 핀 모양으로 시각적 앵커링됩니다.
        ],
      ),
      const SizedBox(height: 8),
      // 퍼센트 표시 텍스트
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '문턱 달성률: ${(ratio * 100).toInt()}%',
            style: TextStyle(
              color: gaugeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '공제 문턱: ${_numberFormat.format(threshold.toInt())}원',
            style: const TextStyle(
              color: Color(0xFF8B95A1),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ],
  );
}
```

---

## 📋 검증 계획

### 수동 및 코드 검토 검증
*   `home_screen.dart`의 `_buildExpenseCard()` 메서드에 신규 프로그레스 바가 잘 바인딩되었는지 확인합니다.
*   연봉(`_salaryController`)과 실제 지출액(`_creditCardController`, `_debitCashController`)이 입력됨에 따라 `ratio`와 `gaugeColor`가 올바르게 갱신되는지 시뮬레이션 데이터를 대입해 정합성을 검증합니다.
