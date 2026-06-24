/// 시스템(앱 기본) 알림 카탈로그 — 토글 전용. 사용자가 만들지 않고 켜고/끄기만 한다.
/// reminders 테이블이 아니라 코드에 정적 정의하고, on/off는 reminder_settings(key)로 저장.
/// 켜짐 판정은 "행이 없으면 ON"(getReminderSettings에 키 없으면 켜진 것).
library;

enum SysCategory { deadline, moment } // 기한 · 맞춤(이벤트)

extension SysCategoryX on SysCategory {
  String get label => this == SysCategory.deadline ? '기한' : '맞춤';
}

/// 큐레이션된 시스템 알림 1건.
class SystemReminder {
  final String key;        // reminder_settings 안정 키
  final int notifId;       // flutter_local_notifications 고정 ID (1001~)
  final SysCategory category;
  final String title;      // 알림 제목
  final String body;       // 알림 본문
  final String scheduleLabel; // 표시용 ("매년 1월 15일", "공제 문턱 도달 시")
  final int? month;        // 예약 월 (이벤트형이면 null)
  final int? day;          // 예약 일
  final int hour;          // 예약 시각(시)
  final bool employee;     // 직장인·N잡러 대상
  final bool business;     // 프리랜서·N잡러 대상

  const SystemReminder({
    required this.key,
    required this.notifId,
    required this.category,
    required this.title,
    required this.body,
    required this.scheduleLabel,
    this.month,
    this.day,
    this.hour = 9,
    this.employee = false,
    this.business = false,
  });

  bool get isEvent => month == null || day == null;

  bool appliesTo(String userType) {
    final isEmp = userType == '직장인' || userType == 'N잡러';
    final isBiz = userType == '프리랜서' || userType == 'N잡러';
    return (employee && isEmp) || (business && isBiz);
  }
}

/// 전체 카탈로그. ReminderScheduler의 고정 ID·문구와 1:1로 맞춘다.
const List<SystemReminder> kSystemReminderCatalog = [
  // ── 기한 (직장인·N잡러) ──
  SystemReminder(
    key: 'sys_year_end',
    notifId: 1001,
    category: SysCategory.deadline,
    title: '연말정산 시즌이 왔어요',
    body: '홈택스 간소화 자료가 열렸어요. 놓친 공제가 없는지 확인해보세요.',
    scheduleLabel: '매년 1월 15일',
    month: 1, day: 15,
    employee: true,
  ),
  SystemReminder(
    key: 'sys_year_end_refund',
    notifId: 1006,
    category: SysCategory.deadline,
    title: '연말정산 추가 환급, 아직 늦지 않았어요',
    body: '3/10까지 — 회사에 못 낸 공제를 직접 신고해 돌려받으세요.',
    scheduleLabel: '매년 3월 5일',
    month: 3, day: 5,
    employee: true,
  ),
  SystemReminder(
    key: 'sys_prep_december',
    notifId: 1010,
    category: SysCategory.deadline,
    title: '연말정산 막차 — 올해가 가기 전에',
    body: '카드·기부·의료비는 12월 31일까지 쓴 만큼만 공제돼요. 막판 점검하세요.',
    scheduleLabel: '매년 12월 1일',
    month: 12, day: 1,
    employee: true,
  ),

  // ── 기한 (공통) ──
  SystemReminder(
    key: 'sys_may_prep',
    notifId: 1012,
    category: SysCategory.deadline,
    title: '종합소득세 신고 준비하세요',
    body: '한 달 뒤면 5월 종합소득세 신고예요. 경비·공제 자료를 미리 챙기면 5월이 편해요.',
    scheduleLabel: '매년 4월 25일',
    month: 4, day: 25,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_may_start',
    notifId: 1002,
    category: SysCategory.deadline,
    title: '5월 종합소득세 신고 시작',
    body: '오늘부터 종합소득세 신고예요. 환급 대상인지 미리 확인해보세요.',
    scheduleLabel: '매년 5월 1일',
    month: 5, day: 1,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_may_dday',
    notifId: 1003,
    category: SysCategory.deadline,
    title: '종합소득세 신고 마감 임박',
    body: '5월 말이 신고 마감이에요. 아직이라면 지금 준비하세요.',
    scheduleLabel: '매년 5월 25일',
    month: 5, day: 25,
    employee: true, business: true,
  ),
  SystemReminder(
    key: 'sys_eitc',
    notifId: 1013,
    category: SysCategory.deadline,
    title: '근로·자녀장려금 신청 기간',
    body: '5월 한 달간 정기신청이에요. 소득이 적은 가구라면 놓치지 말고 신청하세요.',
    scheduleLabel: '매년 5월 1일',
    month: 5, day: 1,
    employee: true, business: true,
  ),

  // ── 기한 (프리랜서·N잡러) ──
  SystemReminder(
    key: 'sys_vat_jan',
    notifId: 1007,
    category: SysCategory.deadline,
    title: '부가가치세 확정신고(2기)',
    body: '1/25까지 — 작년 하반기분 부가세를 신고·납부하세요.',
    scheduleLabel: '매년 1월 20일',
    month: 1, day: 20,
    business: true,
  ),
  SystemReminder(
    key: 'sys_vat_jul',
    notifId: 1008,
    category: SysCategory.deadline,
    title: '부가가치세 확정신고(1기)',
    body: '7/25까지 — 올해 상반기분 부가세를 신고·납부하세요.',
    scheduleLabel: '매년 7월 20일',
    month: 7, day: 20,
    business: true,
  ),
  SystemReminder(
    key: 'sys_midprepay',
    notifId: 1009,
    category: SysCategory.deadline,
    title: '종합소득세 중간예납',
    body: '11/30까지 — 상반기 소득 기준으로 미리 납부해요.',
    scheduleLabel: '매년 11월 25일',
    month: 11, day: 25,
    business: true,
  ),

  // ── 맞춤 (이벤트, 직장인·N잡러) ──
  SystemReminder(
    key: 'sys_threshold',
    notifId: 1005,
    category: SysCategory.moment,
    title: '신용카드 공제 문턱 돌파',
    body: '연봉의 25%를 넘겼어요. 지금부터는 체크·현금이 공제율 2배(30%)예요.',
    scheduleLabel: '공제 문턱(연봉 25%) 도달 시',
    employee: true,
  ),
  SystemReminder(
    key: 'sys_threshold_near',
    notifId: 1011,
    category: SysCategory.moment,
    title: '공제 문턱이 코앞이에요',
    body: '신용카드가 공제 문턱의 80%에 도달했어요. 곧 체크·현금 공제율이 2배가 돼요.',
    scheduleLabel: '공제 문턱 80% 도달 시',
    employee: true,
  ),
];

/// 유형에 해당하는 시스템 알림만.
List<SystemReminder> systemRemindersFor(String userType) =>
    kSystemReminderCatalog.where((s) => s.appliesTo(userType)).toList();

SystemReminder? systemReminderByKey(String key) {
  for (final s in kSystemReminderCatalog) {
    if (s.key == key) return s;
  }
  return null;
}
