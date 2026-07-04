import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../../core/notifications/reminder.dart';
import '../../core/notifications/custom_reminder_service.dart';
import '../../core/notifications/system_reminder_catalog.dart';
import '../../core/data/db_helper.dart';
import '../screens/reminder_list_screen.dart';

/// 홈 — 사용자 맞춤 리마인더 아코디언 카드 (지출 카드와 절세 카드 사이).
/// 접힌 상태: 다음 알림 요약. 펼친 상태(부드러운 애니메이션): 목록.
/// 알림 '추가' 기능은 다음 패스에서 제공 — 지금은 읽기 전용.
class ReminderCard extends StatefulWidget {
  final String userType;
  const ReminderCard({super.key, this.userType = '직장인'});

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

/// 카드 요약용 — 다음에 울릴 알림 한 건(사용자+시스템 통합).
class _Upcoming {
  final DateTime when;
  final String title;
  final String label; // D-day 또는 주기 라벨
  const _Upcoming(this.when, this.title, this.label);
}

class _ReminderCardState extends State<ReminderCard> {
  List<Reminder> _reminders = [];
  Map<String, bool> _sysSettings = {};
  bool _expanded = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await customReminderService.list();
    final settings = await dbService.getReminderSettings();
    if (!mounted) return;
    setState(() {
      _reminders = list;
      _sysSettings = settings;
      _loading = false;
    });
  }

  String _ddayFor(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(when.year, when.month, when.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'D-DAY';
    if (diff > 0) return 'D-$diff';
    return '지남';
  }

  /// 사용자 + 시스템(기한) 알림을 합쳐 가장 가까운 다음 한 건.
  _Upcoming? get _next {
    final cands = <_Upcoming>[];
    // 사용자 알림 (만료된 단발 알림 제외)
    final now = DateTime.now();
    for (final r in _reminders.where((r) => r.enabled)) {
      final when = CustomReminderService.nextInstance(r);
      if (r.frequency == ReminderFrequency.once && !when.isAfter(now)) continue;
      final label = r.frequency == ReminderFrequency.once ? _ddayFor(when) : r.frequency.label;
      cands.add(_Upcoming(when, r.title, label));
    }
    // 시스템 기한 알림 (없으면 ON)
    for (final s in systemRemindersFor(widget.userType)) {
      if (s.isEvent) continue;
      if (_sysSettings[s.key] == false) continue;
      var when = DateTime(now.year, s.month!, s.day!, s.hour);
      if (!when.isAfter(now)) when = DateTime(now.year + 1, s.month!, s.day!, s.hour);
      cands.add(_Upcoming(when, s.title, _ddayFor(when)));
    }
    if (cands.isEmpty) return null;
    cands.sort((a, b) => a.when.compareTo(b.when));
    return cands.first;
  }

  String _timeLabel(Reminder r) {
    final h = r.notifyHour.toString().padLeft(2, '0');
    final m = r.notifyMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 일정 한 줄 설명 — 주기별 분기.
  String _subtitle(Reminder r) {
    final t = _timeLabel(r);
    switch (r.frequency) {
      case ReminderFrequency.once:
        return '${DateFormat('M월 d일').format(r.notifyDate)} $t';
      case ReminderFrequency.daily:
        return '매일 $t';
      case ReminderFrequency.weekly:
        final wd = kWeekdayLabels[((r.weekday ?? r.notifyDate.weekday) - 1) % 7];
        return '매주 $wd요일 $t';
      case ReminderFrequency.monthly:
        return '매월 ${r.notifyDate.day}일 $t';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 헤더: 라벨+화살표(접힘) / 추가·관리 링크(우상단) ──
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('리마인더', style: AppTheme.label(context)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.expand_more_rounded, size: 20, color: tert),
                ),
              ]),
            ),
            const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openManager,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 16, color: accent),
                const SizedBox(width: 4),
                Text(_reminders.isEmpty ? '알림 추가' : '리마인더 관리',
                    style: AppTheme.sans(13, accent, weight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
        // ── 펼침 영역 — AnimatedSize로 높이 전환 ──
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _expandedContent(ink, sub, tert, accent)
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }

  Widget _expandedContent(Color ink, Color sub, Color tert, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_reminders.isEmpty)
            Text('가계부 기록·월세·건강검진처럼 챙길 일을 알림으로 만들어 보세요.',
                style: AppTheme.sans(12.5, tert, height: 1.5))
          else
            ..._reminders.take(3).map((r) => _reminderRow(r, ink, sub, tert, accent)),
        ],
      ),
    );
  }

  Future<void> _openManager() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ReminderListScreen(userType: widget.userType)));
    await _load();
  }

  Widget _reminderRow(Reminder r, Color ink, Color sub, Color tert, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // D-day(단발) 또는 주기 배지
          SizedBox(
            width: 54,
            child: Text(
                r.frequency == ReminderFrequency.once
                    ? _ddayFor(CustomReminderService.nextInstance(r))
                    : r.frequency.label,
                style: AppTheme.serif(15, r.enabled ? ink : tert,
                    weight: FontWeight.w700, spacing: -0.5, height: 1.0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(13.5, r.enabled ? ink : tert,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_subtitle(r), style: AppTheme.sans(11.5, tert)),
              ],
            ),
          ),
          // on/off 스위치 (기존 알림 끄고 켜기는 가능)
          Switch(
            value: r.enabled,
            activeColor: accent,
            onChanged: (v) async {
              await customReminderService.toggle(r, v);
              await _load();
            },
          ),
        ],
      ),
    );
  }
}
