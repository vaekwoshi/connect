import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/db_helper.dart';
import '../security/notification_helper.dart';
import 'reminder.dart';

/// 사용자 맞춤 리마인더 서비스 — DB(reminders 테이블) CRUD + 시스템 알림 예약.
/// 알림 ID는 2000번대(리마인더 id + base)로 고정 세무 일정(1001~1009)과 분리.
class CustomReminderService {
  static const int _notifBase = 2000;

  Future<List<Reminder>> list() async {
    final rows = await dbService.getReminders();
    return rows.map((r) => Reminder.fromMap(r)).toList();
  }

  /// 생성 — DB 저장 후 notifId를 부여하고 활성 시 알림 예약.
  Future<Reminder> add(Reminder r) async {
    final id = await dbService.insertReminder(r.toMap());
    final saved = r.copyWith(id: id, notifId: _notifBase + (id <= 0 ? 1 : id));
    await dbService.updateReminder(saved.toMap());
    if (saved.enabled) await _schedule(saved);
    return saved;
  }

  /// 수정 — 기존 알림 취소 후 활성 시 재예약.
  Future<void> update(Reminder r) async {
    await dbService.updateReminder(r.toMap());
    if (r.notifId != null) await _safeCancel(r.notifId!);
    if (r.enabled) await _schedule(r);
  }

  Future<void> remove(Reminder r) async {
    if (r.notifId != null) await _safeCancel(r.notifId!);
    if (r.id != null) await dbService.deleteReminder(r.id!);
  }

  Future<Reminder> toggle(Reminder r, bool on) async {
    final updated = r.copyWith(enabled: on);
    await update(updated);
    return updated;
  }

  /// 기록 넛지 시드 — 최초 1회만 reminders에 'record' 항목을 만든다(매월·급여일·10시).
  /// 구 ReminderScheduler.scheduleMonthlyNudge를 대체. 한 번 만들면 사용자가 자유 편집.
  Future<void> ensureRecordSeed({required int payDay}) async {
    final all = await list();
    final exists = all.any((r) => r.kind == 'record');
    if (exists) return;
    final now = DateTime.now();
    final day = payDay.clamp(1, 28);
    await add(Reminder(
      title: '이번 달 가계부 기록하기',
      kind: 'record',
      frequency: ReminderFrequency.monthly,
      notifyDate: DateTime(now.year, now.month, day),
      notifyHour: 10,
      notifyMinute: 0,
      enabled: true,
    ));
  }

  /// 다음으로 울릴 활성 리마인더(요약 표시용).
  Future<Reminder?> nextUpcoming() async {
    final all = await list();
    final upcoming = all.where((r) => r.enabled).toList()
      ..sort((a, b) => nextInstance(a).compareTo(nextInstance(b)));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// 반복 주기에 맞춘 '다음 발화 시각'(미래). 표시·예약 공통.
  static DateTime nextInstance(Reminder r, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final h = r.notifyHour, m = r.notifyMinute;
    switch (r.frequency) {
      case ReminderFrequency.once:
        return r.scheduledDateTime;
      case ReminderFrequency.daily:
        var when = DateTime(now.year, now.month, now.day, h, m);
        if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
        return when;
      case ReminderFrequency.weekly:
        final target = r.weekday ?? r.notifyDate.weekday; // 1=월…7=일
        var when = DateTime(now.year, now.month, now.day, h, m);
        var add = (target - when.weekday) % 7;
        if (add < 0) add += 7;
        when = when.add(Duration(days: add));
        if (!when.isAfter(now)) when = when.add(const Duration(days: 7));
        return when;
      case ReminderFrequency.monthly:
        final day = r.notifyDate.day.clamp(1, 28); // 모든 달 존재 보장
        var when = DateTime(now.year, now.month, day, h, m);
        if (!when.isAfter(now)) {
          when = now.month == 12
              ? DateTime(now.year + 1, 1, day, h, m)
              : DateTime(now.year, now.month + 1, day, h, m);
        }
        return when;
    }
  }

  /// 반복 주기 → 네이티브 매치 컴포넌트.
  static DateTimeComponents? _matchFor(ReminderFrequency f) {
    switch (f) {
      case ReminderFrequency.once:
        return null;
      case ReminderFrequency.daily:
        return DateTimeComponents.time;
      case ReminderFrequency.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case ReminderFrequency.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
    }
  }

  Future<void> _schedule(Reminder r) async {
    final notifId = r.notifId;
    if (notifId == null) return;
    final when = nextInstance(r);
    // 단발인데 이미 지난 시각이면 예약하지 않는다.
    if (r.frequency == ReminderFrequency.once && !when.isAfter(DateTime.now())) {
      return;
    }
    try {
      await notificationHelper.scheduleAtDate(
        id: notifId,
        title: '세끌 리마인더',
        body: r.title,
        when: when,
        matchComponents: _matchFor(r.frequency),
      );
    } catch (_) {
      // 웹 등 미지원 환경에서는 예약을 건너뛴다(UI는 유지).
    }
  }

  Future<void> _safeCancel(int id) async {
    try {
      await notificationHelper.cancel(id);
    } catch (_) {}
  }
}

final customReminderService = CustomReminderService();
