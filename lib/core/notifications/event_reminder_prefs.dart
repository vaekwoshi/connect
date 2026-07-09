import '../data/db_helper.dart';

/// 이벤트 트리거형 기본 제공 알림(예산 알림·미기록 넛지)의 코드 기본값.
/// DB에 행이 없으면 이 값을 쓴다(reminder_settings의 "행 없으면 ON" 관례와 동일 정신).
const Map<String, Map<String, int>> kEventReminderDefaults = {
  'budget_alert': {'hour': 20, 'minute': 0},
  'inactivity_nudge': {'hour': 9, 'minute': 0},
  'income_inactivity_nudge': {'hour': 9, 'minute': 0},
  'recurring_expense_alert': {'hour': 9, 'minute': 0},
  'tax_reserve_shortfall': {'hour': 9, 'minute': 0},
};

class ResolvedEventPref {
  final bool enabled;
  final int hour;
  final int minute;
  const ResolvedEventPref({required this.enabled, required this.hour, required this.minute});
}

/// DB 저장값 + 코드 기본값을 합쳐 실제 사용할 on/off·시각을 계산.
Future<ResolvedEventPref> resolveEventPref(String key) async {
  final all = await dbService.getEventReminderPrefs();
  final defaults = kEventReminderDefaults[key]!;
  final row = all[key];
  return ResolvedEventPref(
    enabled: (row?['enabled'] as bool?) ?? true,
    hour: (row?['hour'] as int?) ?? defaults['hour']!,
    minute: (row?['minute'] as int?) ?? defaults['minute']!,
  );
}
