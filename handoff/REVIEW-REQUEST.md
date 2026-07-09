# Review Request — Step 1
*Written by Builder. Read by Reviewer.*

Ready for Review: YES

---

## What Was Built

기록 넛지(`kind='record'`) 시드 문구를 userType별로 분기했다(프리랜서는 "월급날" 전제 없는 문구, 그 외는 기존 유지 + 기존 프리랜서 유저 1회 마이그레이션). 5월 종합소득세 "신고 시작"(`sys_may_start`) 알림에 프리랜서·N잡러 대상 3.3%/8.8% 원천징수 정산(환급/추가납부) 안내를 덧붙였다.

## Files Changed

| File | Lines | Change |
|---|---|---|
| `lib/core/notifications/custom_reminder_service.dart` | 51-76 | `ensureRecordSeed`에 `userType` 파라미터 추가, 제목 분기 + 기존 프리랜서 시드 제목 1회 마이그레이션 fix-up |
| `lib/core/notifications/reminder_scheduler.dart` | 24 | `scheduleAll` → `ensureRecordSeed` 호출에 `userType` 전달 |
| `lib/core/notifications/reminder_scheduler.dart` | 51-54, ~70-73 | `sys_may_start`에 `_appendWithholdingNote` 호출 추가 + 새 private 메서드 추가 |

## Open Questions

- 마이그레이션 fix-up은 `existing.first`(가장 먼저 조회된 record 리마인더)만 검사한다 — `kind='record'`는 설계상 유저당 최대 1개만 존재하므로 문제 없다고 판단했으나, 확인 부탁.
- `_appendWithholdingNote`는 `_appendReserveStatus`와 달리 async/try-catch가 없다(DB나 외부 계산에 의존하지 않는 순수 문자열이라 불필요하다고 판단) — 의도한 설계인지 확인 부탁.

## Known Gaps Logged

- KG-6c(지급명세서 발급 확인), KG-6d(건강보험 지역가입자 전환 안내) — 이번 스텝 범위 밖, BUILD-LOG에 이미 기록됨.
