# P1 (UI 및 사용성 개선) 구현 계획

P0 (핵심 특허 청구항) 구현이 완료됨에 따라, P1 단계 작업을 진행하고자 합니다. P1 단계의 핵심은 **"복잡한 홈 화면 간소화 및 도구 접근성 강화"**입니다.

## User Review Required

> [!IMPORTANT]
> **P1-1 지출 목표 카드 리팩토링 방식에 대한 확인이 필요합니다.**
> 현재 홈 화면(`home_screen.dart`)에 노출되어 있던 '지출 목표' 및 '실제 지출' 직접 입력 폼을 제거하고, 별도의 새 스크린(`ExpenseTargetScreen`)으로 분리합니다.

## Proposed Changes

### 1. 홈 화면 (Home Screen) 리팩토링
#### [MODIFY] [home_screen.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/%EC%84%B8%EB%81%8C/lib/ui/screens/home_screen.dart)
- **지출 목표 카드 간소화 (P1-1)**: 인라인 텍스트 입력 필드를 삭제하고, 누르면 새 창(`ExpenseTargetScreen`)으로 이동하도록 수정합니다. (바텀 시트 금지 규칙 준수)
- **프리랜서 경비 관리 카드 (P1-2)**: '프리랜서/N잡러' 모드 시 홈 화면에 '경비 증빙 현황' 카드를 추가합니다. "다음 세율 구간까지 000원의 경비가 더 필요해요"와 같은 절세 넛지를 텍스트로 노출합니다.
- **간편장부 도구 연결 (P1-3)**: 하단 '도구' 탭의 리스트에 `[간편장부]` 항목을 명시적으로 추가하고 `FreelancerBookScreen`으로 연결합니다.

### 2. 지출 목표 상세 화면 신규 생성
#### [NEW] [expense_target_screen.dart](file:///c:/Users/vedja/.gemini/antigravity/scratch/%EC%84%B8%EB%81%8C/lib/ui/screens/expense_target_screen.dart)
- 기존 홈 화면에 있던 신용카드, 체크카드, 현금영수증 입력란을 이 스크린의 하위 메뉴(입력 폼)로 이동합니다.
- 사용자에게 "이번 달 지출 목표"를 설정하게 하고, 설정 금액 대비 현재 사용액(신용/체크/현금)을 시각적인 게이지 바 형태로 보여줍니다.

## Verification Plan
### Manual Verification
- 에뮬레이터에서 홈 화면의 지출 목표 카드를 터치하여 새 화면으로 넘어가는지 테스트
- 도구 탭에서 간편장부 버튼을 터치하여 정상적으로 진입하는지 확인
- 프리랜서 모드일 때 경비 관리 넛지 카드가 제대로 렌더링되는지 확인