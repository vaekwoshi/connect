# Architect Brief
*Written by Architect. Read by Builder and Reviewer.*
*Overwrite this file each step — it is not a log, it is the current active brief.*

---

## Step 1 — 기록 넛지 문구 userType 분기 + 5월 종합소득세 3.3%/8.8% 정산 안내

### Context (current code, confirmed by reading the files — do not re-derive)
- `CustomReminderService.ensureRecordSeed({required int payDay})` (`lib/core/notifications/custom_reminder_service.dart:53`) creates a one-time `kind='record'` reminder titled `'월급날이에요! 가계부에 기록해볼까요?'` for every user regardless of `userType`. It only ever runs once (`if (exists) return`).
- Called from `ReminderScheduler.scheduleAll({required int payDay, required String userType})` (`lib/core/notifications/reminder_scheduler.dart:21-25`) — `userType` is already available there but not passed through to `ensureRecordSeed`.
- `kind='record'` is a "fixed kind" reminder — `reminder_form_screen.dart`'s `_isFixedKind` locks title/frequency, only the fire time is user-editable. So a wrong title persists until we fix it in code/DB, not something the user can edit away.
- `ReminderScheduler.scheduleTaxSeason(String userType)` (`reminder_scheduler.dart:38-64`) iterates `kSystemReminderCatalog` and already has a precedent for userType-conditional body append: `sys_may_prep` gets `_appendReserveStatus` appended for 프리랜서/N잡러 (annual tax estimate). `sys_may_start` (`system_reminder_catalog.dart:139-149`, body: `'오늘부터 종합소득세 신고예요. 환급 대상인지 미리 확인해보세요.'`) has no such append yet.
- Freelancer/N잡러 income entries track `isWithheld` (원천징수 후 순액) at 3.3% (사업소득) or 8.8% (기타소득) — see `IncomeEntry` in 요약.md. The withheld amount is settled against actual tax owed at May filing (환급 or 추가납부). This mechanism is currently never explained in any notification.

### Decisions
- Freelancer replacement title for the 'record' seed: **`'가계부에 오늘 기록해볼까요?'`** (no fixed-payday premise; N잡러/직장인 keep the existing `'월급날이에요! 가계부에 기록해볼까요?'` since they do have a fixed pay day).
- One-time DB fix-up for users who already have a seeded `record` reminder with the old title and `userType == '프리랜서'`: update title only (not time, not frequency, not `kind`). Do this inside `ensureRecordSeed` (or a sibling method called from `scheduleAll`) — check `exists` first; if a 프리랜서's existing record reminder's title still equals the old 월급날 string, overwrite it once.
- 3.3%/8.8% settlement note goes on **`sys_may_start`** only (not `sys_may_prep`/`sys_may_dday` — keep this step tight), for 프리랜서/N잡러 only, appended the same way `_appendReserveStatus` is appended for `sys_may_prep`.
- Suggested appended text (adjust wording to match existing tone, don't change meaning): `' 사업소득(3.3%)·기타소득(8.8%)으로 미리 낸 세금은 실제 세액과 정산돼 돌려받거나(환급) 더 낼(추가납부) 수 있어요.'`

### Build Order
1. `custom_reminder_service.dart`: add `required String userType` param to `ensureRecordSeed`; branch title on `userType == '프리랜서'`; add the one-time title fix-up for already-seeded 프리랜서 rows described above.
2. `reminder_scheduler.dart`: pass `userType` from `scheduleAll` into `ensureRecordSeed`.
3. `reminder_scheduler.dart`: add `_appendWithholdingNote(body, userType)` (mirror `_appendReserveStatus`'s shape) and call it for `sys_may_start` when `userType == '프리랜서' || userType == 'N잡러'`, same pattern as the existing `sys_may_prep` branch at line 51-53.
4. Run `test/engine_regression_test.dart` — must stay green (this step shouldn't touch tax_engine, but confirm no incidental breakage).

### Flags
- Do not touch `sys_may_prep` or `sys_may_dday` bodies — out of scope for this step.
- Do not build KG-6c (지급명세서 발급 확인) or KG-6d (건강보험 지역가입자 전환 안내) — explicitly deferred pending tax-policy detail confirmation from Project Owner. If you notice a natural extension point while in this code, log it to Known Gaps, do not implement.
- `record` reminder is fixed-kind — do not add new user-editable fields to it as part of this fix.

### Definition of Done
- [ ] 프리랜서 신규 유저: 'record' 시드 제목이 "가계부에 오늘 기록해볼까요?"
- [ ] N잡러·직장인 신규 유저: 기존 "월급날이에요! 가계부에 기록해볼까요?" 유지 (회귀 없음)
- [ ] 기존에 이미 시드된 프리랜서 유저의 'record' 제목이 앱 재실행(`scheduleAll` 호출) 시 새 문구로 1회 갱신됨
- [ ] `sys_may_start` 알림이 프리랜서·N잡러에게는 3.3%/8.8% 정산 안내 문구가 붙어서 나감, 직장인은 기존 문구 그대로
- [ ] `flutter test` (engine_regression_test.dart) 전원 통과

---

## Builder Plan
*Builder adds their plan here before building. Architect reviews and approves.*

[Builder writes plan here]

Architect approval: [ ] Approved / [ ] Redirect — see notes below
