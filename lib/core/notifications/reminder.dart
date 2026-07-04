/// 알림 반복 주기 (v21). 네이티브 matchDateTimeComponents에 1:1 매핑된다.
/// once=단발 · daily=매일(시·분) · weekly=매주(요일) · monthly=매월(일).
enum ReminderFrequency { once, daily, weekly, monthly }

extension ReminderFrequencyX on ReminderFrequency {
  String get key => name; // 'once' | 'daily' | 'weekly' | 'monthly'

  String get label {
    switch (this) {
      case ReminderFrequency.once:
        return '한 번';
      case ReminderFrequency.daily:
        return '매일';
      case ReminderFrequency.weekly:
        return '매주';
      case ReminderFrequency.monthly:
        return '매월';
    }
  }

  static ReminderFrequency fromKey(String? k) {
    switch (k) {
      case 'daily':
        return ReminderFrequency.daily;
      case 'weekly':
        return ReminderFrequency.weekly;
      case 'monthly':
        return ReminderFrequency.monthly;
      default:
        return ReminderFrequency.once;
    }
  }
}

/// 요일 한글 라벨 (DateTime.weekday: 1=월 … 7=일).
const List<String> kWeekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 사용자 맞춤 리마인더 모델 (v21).
/// 항목·반복 주기·알림 발화 날짜/시각을 담고 시스템 알림 예약과 연결된다.
class Reminder {
  final int? id;
  final String title;       // 항목명 (알림 본문)
  final String kind;        // 'custom' | 'tax' | 'record' | 'threshold'
  final DateTime? dueDate;  // 기한 (선택; 시스템 기한 알림용)
  final DateTime notifyDate; // 알림 발화 기준 날짜 (monthly=일, once=정확 날짜)
  final int notifyHour;
  final int notifyMinute;
  final ReminderFrequency frequency; // 반복 주기
  final int? weekday;       // 매주용 요일 단일값(구버전 호환) — 표시는 weekdays 우선
  final List<int> weekdays; // 매주용 요일 목록 (1=월 … 7=일). 비어있으면 notifyDate.weekday 1개로 취급.
  final bool enabled;
  final int? notifId;       // flutter_local_notifications id

  const Reminder({
    this.id,
    required this.title,
    this.kind = 'custom',
    this.dueDate,
    required this.notifyDate,
    this.notifyHour = 9,
    this.notifyMinute = 0,
    this.frequency = ReminderFrequency.once,
    this.weekday,
    this.weekdays = const [],
    this.enabled = true,
    this.notifId,
  });

  /// 매주 반복 시 실제로 쓸 요일 목록(단일값 구버전 폴백 포함).
  List<int> get effectiveWeekdays =>
      weekdays.isNotEmpty ? weekdays : [weekday ?? notifyDate.weekday];

  bool get isRepeating => frequency != ReminderFrequency.once;

  /// 단발 알림이 울릴 정확한 시각(날짜 + 시·분). 반복 알림의 '다음 발화'는 서비스가 계산한다.
  DateTime get scheduledDateTime => DateTime(
      notifyDate.year, notifyDate.month, notifyDate.day, notifyHour, notifyMinute);

  Reminder copyWith({
    int? id,
    String? title,
    String? kind,
    DateTime? dueDate,
    DateTime? notifyDate,
    int? notifyHour,
    int? notifyMinute,
    ReminderFrequency? frequency,
    int? weekday,
    List<int>? weekdays,
    bool? enabled,
    int? notifId,
  }) =>
      Reminder(
        id: id ?? this.id,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        dueDate: dueDate ?? this.dueDate,
        notifyDate: notifyDate ?? this.notifyDate,
        notifyHour: notifyHour ?? this.notifyHour,
        notifyMinute: notifyMinute ?? this.notifyMinute,
        frequency: frequency ?? this.frequency,
        weekday: weekday ?? this.weekday,
        weekdays: weekdays ?? this.weekdays,
        enabled: enabled ?? this.enabled,
        notifId: notifId ?? this.notifId,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'kind': kind,
        'due_date': dueDate?.toIso8601String(),
        'notify_date': notifyDate.toIso8601String(),
        'notify_hour': notifyHour,
        'notify_minute': notifyMinute,
        'frequency': frequency.key,
        'weekday': weekdays.isNotEmpty ? weekdays.first : weekday,
        'weekdays': weekdays.isNotEmpty ? weekdays.join(',') : null,
        'enabled': enabled,
        'notif_id': notifId,
      };

  factory Reminder.fromMap(Map<String, dynamic> m) {
    // 구버전 호환: frequency 없고 repeat_monthly만 있으면 monthly로 해석.
    final ReminderFrequency freq;
    if (m['frequency'] != null) {
      freq = ReminderFrequencyX.fromKey(m['frequency'] as String?);
    } else if (m['repeat_monthly'] == true || m['repeat_monthly'] == 1) {
      freq = ReminderFrequency.monthly;
    } else {
      freq = ReminderFrequency.once;
    }
    // 구버전 호환: weekdays(복수)가 없으면 weekday(단일) 하나짜리 목록으로 해석.
    final wdsStr = m['weekdays'] as String?;
    final wds = (wdsStr != null && wdsStr.isNotEmpty)
        ? wdsStr.split(',').map((e) => int.tryParse(e)).whereType<int>().toList()
        : <int>[];
    return Reminder(
      id: m['id'] as int?,
      title: (m['title'] as String?) ?? '',
      kind: (m['kind'] as String?) ?? 'custom',
      dueDate: (m['due_date'] as String?) != null
          ? DateTime.tryParse(m['due_date'] as String)
          : null,
      notifyDate:
          DateTime.tryParse((m['notify_date'] as String?) ?? '') ?? DateTime.now(),
      notifyHour: (m['notify_hour'] as int?) ?? 9,
      notifyMinute: (m['notify_minute'] as int?) ?? 0,
      frequency: freq,
      weekday: m['weekday'] as int?,
      weekdays: wds,
      enabled: m['enabled'] == true || m['enabled'] == 1,
      notifId: m['notif_id'] as int?,
    );
  }

  /// 유형 한글 라벨.
  String get kindLabel {
    switch (kind) {
      case 'tax':
        return '세무 일정';
      case 'record':
        return '기록';
      case 'threshold':
        return '공제 문턱';
      default:
        return '내가 만든 알림';
    }
  }
}
