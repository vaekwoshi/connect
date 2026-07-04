import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
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

  /// 이번 달 지출 목표 80% 도달 — 즉시 1회.
  static Future<void> showBudgetNear() => _fireEvent('sys_budget_near');

  /// 이번 달 지출 목표 초과 — 즉시 1회.
  static Future<void> showBudgetOver() => _fireEvent('sys_budget_over');

  static Future<void> _fireEvent(String key) async {
    final s = systemReminderByKey(key);
    if (s == null) return;
    final settings = await dbService.getReminderSettings();
    if (settings[key] == false) return; // 명시적으로 꺼졌을 때만 차단
    await notificationHelper.showImmediateNotification(
      id: s.notifId,
      title: s.title,
      body: s.body,
      logCategory: key,
    );
  }

  /// 월급날 알림 — 매월 [day]일 09:00 반복 (id=2001).
  static Future<void> schedulePayday(int day) async {
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, day, 9);
    if (!when.isAfter(now)) {
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear  = now.month == 12 ? now.year + 1 : now.year;
      when = DateTime(nextYear, nextMonth, day, 9);
    }
    await notificationHelper.scheduleAtDate(
      id: 2001,
      title: '월급날이에요 💰',
      body: '이번 달 급여를 가계부에 기록해 보세요.',
      when: when,
      matchComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  /// 카드 결제일 알림 — [cards] 목록의 각 카드마다 매월 반복 (ids 2100~2199).
  static Future<void> scheduleCardPayments(List<Map<String, dynamic>> cards) async {
    for (int i = 0; i < 100; i++) {
      await notificationHelper.cancel(2100 + i);
    }
    final now = DateTime.now();
    for (int i = 0; i < cards.length; i++) {
      final name = cards[i]['name'] as String;
      final day  = cards[i]['day'] as int;
      var when = DateTime(now.year, now.month, day, 9);
      if (!when.isAfter(now)) {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear  = now.month == 12 ? now.year + 1 : now.year;
        when = DateTime(nextYear, nextMonth, day, 9);
      }
      await notificationHelper.scheduleAtDate(
        id: 2100 + i,
        title: '$name 결제일이에요',
        body: '카드 결제 내역을 가계부에서 확인해 보세요.',
        when: when,
        matchComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  /// 지출 미기록 넛지 — [lastExpenseDate]가 3일 이상 전이면 즉시 1회 (id=2002).
  static Future<void> showNudgeIfInactive(DateTime? lastExpenseDate) async {
    if (lastExpenseDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last  = DateTime(lastExpenseDate.year, lastExpenseDate.month, lastExpenseDate.day);
    if (today.difference(last).inDays >= 3) {
      await notificationHelper.showImmediateNotification(
        id: 2002,
        title: '가계부 기록이 없어요',
        body: '최근 며칠간 지출 기록이 없네요. 잠깐 기록해 볼까요?',
        logCategory: 'ledger_nudge',
      );
    }
  }

  /// 월말 마감 알림 — 이번 달(또는 다음 달) 말일 20:00 (id=2003).
  static Future<void> scheduleMonthEnd() async {
    final now = DateTime.now();
    int year  = now.year;
    int month = now.month;
    int lastDay = DateUtils.getDaysInMonth(year, month);
    var when = DateTime(year, month, lastDay, 20);
    if (!when.isAfter(now)) {
      month   = month == 12 ? 1 : month + 1;
      year    = month == 1  ? year + 1 : year;
      lastDay = DateUtils.getDaysInMonth(year, month);
      when    = DateTime(year, month, lastDay, 20);
    }
    await notificationHelper.scheduleAtDate(
      id: 2003,
      title: '이달 가계부 마감해요',
      body: '이번 달 수입·지출을 확인하고 마무리해 보세요.',
      when: when,
    );
  }
}
