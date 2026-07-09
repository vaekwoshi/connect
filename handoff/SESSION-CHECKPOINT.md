# Session Checkpoint — 2026-07-10 (2)
*Read this before reading anything else. If it covers current state, skip BUILD-LOG.*

---

## Where We Stopped

Step 1(`bbc7d75`)·Step 2(`2185ce6`) 완료 후, 가계부 유형별(직장인/N잡러/프리랜서) 분기가 코드 곳곳에 흩어져 "고칠 때마다 이상해진다"는 문제 제기로 리팩터 착수.
**Step 3 완료·커밋(`12cca53`)** — `lib/core/data/ledger_profile.dart` 신설, `LedgerProfile.of(userType)`를 단일 진실 원천으로 삼아 `day_entry_screen.dart`·`expense_calendar_screen.dart`의 흩어진 `userType == '프리랜서'`류 분기를 전부 profile 필드 참조로 교체(동작 동치 확인, 회귀 53건 통과). `home_screen.dart`는 의도적으로 범위 밖(KG-9).
**Step 4(화면 크롬 7층→4층, `ARCHITECT-BRIEF.md`에 계획 있음) 착수 시도 → BLOCKED.** `flutter build web` + 프리뷰까지 띄웠으나 Flutter 웹이 캔버스 렌더라 프리뷰 도구로 3유형 가계부 화면에 클릭 내비게이션 불가(스크린샷만 가능) — 레이아웃이 실제로 바뀌는 작업이라 시각 검증 없이 진행 안 함. 사용자가 "다음 세션에서 재개(b)"를 선택해 코드 변경 없이 세션 종료.

---

## What Was Decided This Session

- 다음 과제로 KG-6c(지급명세서 확인)·KG-6d(건강보험 미가입 경고) 진행 확정 — 날짜는 3/12(3/10 제출기한 직후), KG-6d는 프리랜서 전용(N잡러 제외)
- 가계부 리팩터는 완전 재작성이 아니라 **LedgerProfile 구조 정리**로 — 데이터·인터랙션(핀치줌·드래그·프리필)은 안 건드림
- Step 4(화면 정리)는 이번엔 함께 묶기로 했으나, 시각 검증 툴링이 막혀 다음 세션으로 이월

---

## Still Open

- **Step 4 재개** — `ARCHITECT-BRIEF.md`의 Step 4 계획대로: 결제수단 스트립+범례 통합, 적립카드 기본 접힘, 뷰탭 정리. **재개 전 먼저 시각 검증 방법부터 확보할 것**(예: `flutter run`으로 사용자가 직접 확인하며 진행, 또는 프리뷰 툴링이 되는 세션 확인) — 검증 없이 레이아웃 코드부터 바꾸지 말 것.
- home_screen.dart의 유형 분기(KG-9)는 LedgerProfile로 아직 안 옮겨짐 — Step 4 이후 후보.
- KG-4 (개인정보처리방침 호스팅) — 보류 중, 명시적 요청 시에만 재개
- KG-7 (`tax_reserve_shortfall` 토글 UI 누락), KG-8 (이벤트형 notifId 대역 충돌 가능성) — 로그만 된 상태, 미착수

---

## Resume Prompt

Copy and paste this to resume:

---

You are Arch on the 세끌 (Sekkeul) project.
Read `handoff/SESSION-CHECKPOINT.md`, then `ARCHITECT.md`, then `handoff/ARCHITECT-BRIEF.md`'s Step 4 section.
We're resuming the ledger chrome cleanup (Step 4) that was blocked last session on visual-verification tooling (Flutter web preview can't click-navigate). Confirm with the Project Owner how we'll verify visually this time before touching layout code, then proceed.

---

## Version Check
version_notified:
