# Review Request — Step 2
*Written by Builder. Read by Reviewer.*

Ready for Review: YES

---

## What Was Built

지급명세서 발급 확인 알림(KG-6c)을 새 시스템 알림 카탈로그 항목으로 추가(매년 3/12, 프리랜서·N잡러 대상, 홈택스 확인 경로 안내 포함). 건강보험 미가입 정기 경고(KG-6d)를 기존 이벤트형 리마인더 패턴(`checkTaxReserveShortfall`과 동일 구조)으로 추가 — 프리랜서 전용, `health_enrolled=false`면 다음날 9시 지연 알림, 가입 완료 시 자동 취소. 리마인더 목록의 "기본 제공" 섹션에 프리랜서 전용 토글도 추가.

## Files Changed

| File | Lines | Change |
|---|---|---|
| `lib/core/notifications/system_reminder_catalog.dart` | 13-27, 28-42, ~396-406 | `payment_report` 그룹 + `sys_payment_report_check` 카탈로그 항목(notifId 1004, business만) 신설 |
| `lib/core/notifications/event_reminder_prefs.dart` | 5-12 | `freelancer_health_uninsured` 기본값(9:00) 등록 |
| `lib/core/notifications/reminder_scheduler.dart` | ~269-285 | `checkFreelancerHealthUninsured` 신설, notifId 2006 |
| `lib/ui/screens/home_screen.dart` | ~273-277 | 프리랜서 전용 분기 — 프로필의 `health_enrolled` 조회 후 새 체크 호출 |
| `lib/ui/screens/reminder_list_screen.dart` | 40-41, 55-63, 165-166 | 상태 필드·로드·프리랜서 전용 토글 행 추가 |

## Open Questions

- notifId 1004는 카탈로그 내에서 미사용이었으나, 이벤트형(2000번대) notifId 2006은 커스텀 리마인더와 같은 대역이라 이론상 충돌 가능(KG-8로 로그만 함, 브리프 지시대로 스킴은 안 건드림) — 확인 부탁.
- `home_screen.dart`에 기존 profile 로드 코드가 별도 메서드(`_loadProfile` 계열)에 있어서 재사용하지 않고 `_loadCurrentMonthIncome` 안에서 `dbService.getProfile()`을 새로 호출했음(가벼운 조회라 판단) — 브리프의 "재사용 우선" 지시와 배치되는지 확인 부탁.

## Known Gaps Logged

- KG-7(`tax_reserve_shortfall`이 리마인더 토글 UI에 없음), KG-8(이벤트형 notifId 대역 충돌 가능성) — BUILD-LOG에 기록, 미수정.
