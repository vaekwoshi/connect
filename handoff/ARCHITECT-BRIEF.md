# Architect Brief
*Written by Architect. Read by Builder and Reviewer.*
*Overwrite this file each step — it is not a log, it is the current active brief.*

---

## Step 2 — 지급명세서 발급 확인 알림(KG-6c) + 건강보험 미가입 정기 경고(KG-6d)

### Context (confirmed by reading the code)
- **KG-6c**: `kSystemReminderCatalog` (`lib/core/notifications/system_reminder_catalog.dart:91+`) is the single source for all fixed-date broadcast notifications. Each `SystemReminder` has `employee`/`business` bool gates checked via `appliesTo()` (line 81-87) — `business: true, employee: false` reaches 프리랜서+N잡러 only (see `isBiz` at line 83), which matches what we want (직장인 제외). notifId 1004 is unused (used ids in this file: 1001-1003, 1005-1013, 1016-1020; 1014/1015 are used elsewhere by `idBudgetNear`/`idBudgetOver` in `reminder_scheduler.dart`, avoid those too). Groups are declared in `kGroupLabels`/`kGroupSchedules` maps (lines 13-26, 28-41) — every existing catalog entry has a `group`.
- **KG-6d**: The existing "event-type" pattern (`checkTaxReserveShortfall`, `checkInactivityNudge` in `reminder_scheduler.dart:150-260`) is: (1) key + default hour/minute registered in `kEventReminderDefaults` (`lib/core/notifications/event_reminder_prefs.dart:5-11`), (2) a `ReminderScheduler.checkX(...)` static method that calls `resolveEventPref(key)`, and if the bad condition holds, schedules a delayed notification for "tomorrow at pref.hour/minute" (cancels if condition resolved), (3) called from `home_screen.dart` inside the `!kIsWeb && _notificationsEnabled` block that already gates on userType — the 프리랜서/N잡러 branch is at `home_screen.dart:262-272` (calls `checkTaxReserveShortfall`), (4) registered as a toggle row in `reminder_list_screen.dart`'s "기본 제공" `_section` (lines 156-163, via `_eventRow(key, label, prefState)`).
- `health_enrolled` is a `user_profile` column (`db_helper.dart:260`), read as `profile?['health_enrolled'] == true` (see `reserve_estimator.dart:48`). `home_screen.dart` doesn't currently fetch `profile` in the reminder-check method scope — Bob should fetch it there (`dbService.getProfile()`) alongside the existing 프리랜서/N잡러 block, or find/reuse an existing profile fetch in that method if one exists (check before assuming — don't duplicate an existing call).
- **Note found while researching, not in scope**: `tax_reserve_shortfall` (an existing, already-shipped event-type reminder) is missing from `reminder_list_screen.dart`'s `_eventRow` list (only `budget_alert`/`inactivity_nudge`/`income_inactivity_nudge`/`recurring_expense_alert` are registered there) — users currently cannot toggle it off or edit its time from the UI. This is a pre-existing gap, not something to fix as part of Step 2. Log it as a new Known Gap (KG-7), do not fix.
- **Also pre-existing, not in scope**: hardcoded event-type notifIds (`idInactivityNudge=2002`, `idIncomeInactivityNudge=2004`, `idTaxReserveShortfall=2005`) share the same numeric range as user-created custom reminder notifIds (`CustomReminderService._notifBase=2000 + reminder.id`), so a user reminder with `id==2`, `4`, or `5` could theoretically collide. Do not fix — log as KG-8 if you want it tracked, but do not touch `CustomReminderService`'s id scheme in this step.

### Decisions
- **KG-6c** schedule: **매년 3월 12일** (Project Owner: check as early as possible after the 3/10 submission deadline). notifId **1004**. New group `payment_report` → `kGroupLabels['payment_report'] = '지급명세서'`, `kGroupSchedules['payment_report'] = '매년 3월 12일'`. `employee: false, business: true`.
  - Title: `'지급명세서 제출됐는지 확인해보세요'`
  - Body (Project Owner asked for a how-to-check guide in the copy): `'사업소득·기타소득 지급명세서 제출기한(3/10)이 지났어요. 홈택스 로그인 > My홈택스 > 지급명세서 등 제출내역에서 제출 여부를 확인해보세요.'`
- **KG-6d**: 프리랜서 전용(N잡러 제외 — N잡러는 근로자로서 이미 직장 건강보험에 가입돼 있다고 간주), `health_enrolled == false`일 때만 발동. New event key: `freelancer_health_uninsured`, default `{'hour': 9, 'minute': 0}`. New notifId const `idFreelancerHealthUninsured = 2006` (next free in the 2000-series after 2005 — accept the pre-existing collision-range caveat above, do not redesign the id scheme here).
  - Title: `'건강보험 지역가입자 등록을 확인해보세요'`
  - Body: `'프리랜서는 건강보험을 스스로 가입해야 해요. 내 정보에서 미가입으로 표시돼 있어요 — 지역가입자 등록을 하셨는지 확인해보세요.'`
  - Reminder row label (for `reminder_list_screen.dart`'s "기본 제공" section): `'건강보험 미가입 경고'`. This row should only render when `userType == '프리랜서'` — check how the section currently decides what to show (it currently shows the same 4 rows to everyone) and gate this new row on `widget.userType`.

### Build Order
1. `system_reminder_catalog.dart`: add `kGroupLabels['payment_report']`/`kGroupSchedules['payment_report']`, add the new `SystemReminder` entry (key `sys_payment_report_check`, notifId 1004, per Decisions above).
2. `event_reminder_prefs.dart`: add `'freelancer_health_uninsured': {'hour': 9, 'minute': 0}` to `kEventReminderDefaults`.
3. `reminder_scheduler.dart`: add `static const int idFreelancerHealthUninsured = 2006;` and `checkFreelancerHealthUninsured({required bool healthEnrolled})` mirroring `checkInactivityNudge`'s shape (resolve pref, schedule delayed "tomorrow at pref.hour/minute" if `!healthEnrolled`, else cancel).
4. `home_screen.dart`: in the existing 프리랜서/N잡러 reminder-check block (~line 262), add a 프리랜서-only branch that fetches `health_enrolled` from the profile and calls `ReminderScheduler.checkFreelancerHealthUninsured(...)`.
5. `reminder_list_screen.dart`: add the new toggle row to the "기본 제공" section, gated to `widget.userType == '프리랜서'`.
6. Log KG-7 and KG-8 (see Context notes above) to `handoff/BUILD-LOG.md` Known Gaps — do not fix them.
7. Run `flutter test test/engine_regression_test.dart` and `flutter analyze` on touched files.

### Flags
- Do not fix KG-7 (`tax_reserve_shortfall` missing from reminder_list_screen toggle UI) or KG-8 (notifId range collision) as part of this step — log only.
- Do not build anything for N잡러 health-insurance messaging — explicitly 프리랜서-only per Project Owner decision.
- If `home_screen.dart`'s reminder-check method already fetches the profile map somewhere nearby, reuse it — don't add a second `dbService.getProfile()` call in the same method.

### Definition of Done
- [ ] `sys_payment_report_check` fires 매년 3/12, only for 프리랜서/N잡러, with the 홈택스 확인 경로가 포함된 문구
- [ ] `notification_settings_screen.dart`의 "세금 일정" 섹션에 새 항목이 정상적으로 보임(그룹 라벨 포함)
- [ ] 프리랜서 유저가 `health_enrolled=false`면 다음날 9시(기본, 편집 가능) 알림 예약, `health_enrolled=true`로 바뀌면 자동 취소
- [ ] N잡러·직장인에게는 건강보험 미가입 알림이 절대 발동하지 않음
- [ ] `reminder_list_screen.dart` "기본 제공" 섹션에 새 토글이 프리랜서에게만 보임
- [ ] KG-7, KG-8이 BUILD-LOG Known Gaps에 기록됨(수정 아님)
- [ ] `flutter test` 전원 통과, `flutter analyze` 이상 없음

---

## Step 1 — 기록 넛지 문구 userType 분기 + 5월 종합소득세 3.3%/8.8% 정산 안내 (COMPLETE — 커밋 `bbc7d75`)

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
