import '../security/notification_helper.dart';
import '../data/db_helper.dart';
import 'system_reminder_catalog.dart';
import 'custom_reminder_service.dart';

/// 세끌 시스템 알림 예약 — 세무 기한·문턱 등 '앱 기본' 알림.
/// 정의는 [kSystemReminderCatalog](system_reminder_catalog.dart)가 단일 출처,
/// 켜짐/꺼짐은 reminder_settings(없으면 ON)로 판정한다.
/// 기록 넛지는 더 이상 여기서 고정 예약하지 않고 reminders 테이블 시드로 이관됐다.
class ReminderScheduler {
  static const int idThreshold = 1005; // 공제 문턱 도달(즉시) — 카탈로그 sys_threshold와 동일

  /// 알림 켜짐 시 — 시스템 기한 재예약 + 기록 넛지 시드 보장(유형별).
  static Future<void> scheduleAll({required int payDay, required String userType}) async {
    await scheduleTaxSeason(userType);
    await customReminderService.ensureRecordSeed(payDay: payDay);
  }

  static Future<void> cancelAll() => notificationHelper.cancelAll();

  /// 다가오는 [month]/[day] [hour]시의 가장 가까운 미래 날짜.
  static DateTime _nextOccurrence(int month, int day, {int hour = 9}) {
    final now = DateTime.now();
    var when = DateTime(now.year, month, day, hour);
    if (!when.isAfter(now)) when = DateTime(now.year + 1, month, day, hour);
    return when;
  }

  /// 시스템 기한 알림 — 카탈로그 기반. 유형 비해당·꺼짐 항목은 취소해 잘못된 알림을 막는다.
  static Future<void> scheduleTaxSeason(String userType) async {
    final settings = await dbService.getReminderSettings();
    bool isOn(String key) => settings[key] ?? true; // 행 없으면 ON

    for (final s in kSystemReminderCatalog) {
      if (s.isEvent) continue; // 이벤트형(문턱)은 발생 시점에 show…로 처리
      final active = s.appliesTo(userType) && isOn(s.key);
      if (active) {
        await notificationHelper.scheduleAtDate(
          id: s.notifId,
          title: s.title,
          body: s.body,
          when: _nextOccurrence(s.month!, s.day!, hour: s.hour),
        );
      } else {
        await notificationHelper.cancel(s.notifId);
      }
    }
  }

  /// 공제 문턱 도달 — 즉시 1회. 설정에서 꺼져 있으면 보내지 않는다.
  static Future<void> showThresholdReached() => _fireEvent('sys_threshold');

  /// 공제 문턱 임박(80%) — 즉시 1회. 설정에서 꺼져 있으면 보내지 않는다.
  static Future<void> showThresholdNear() => _fireEvent('sys_threshold_near');

  static Future<void> _fireEvent(String key) async {
    final s = systemReminderByKey(key);
    if (s == null) return;
    final settings = await dbService.getReminderSettings();
    if (settings[key] == false) return; // 명시적으로 꺼졌을 때만 차단
    await notificationHelper.showImmediateNotification(
      id: s.notifId,
      title: s.title,
      body: s.body,
    );
  }
}
