import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/notifications/reminder.dart';
import '../../core/notifications/custom_reminder_service.dart';
import '../../core/notifications/system_reminder_catalog.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../../core/security/notification_helper.dart';
import '../../core/data/db_helper.dart';
import 'reminder_form_screen.dart';

/// 리마인더 관리 — 전용 풀스크린. 4 카테고리 통합:
/// 작성(기록 시드·편집) · 기한(시스템·토글) · 맞춤(이벤트·토글) · 내가 만든(CRUD).
class ReminderListScreen extends StatefulWidget {
  final String userType;
  const ReminderListScreen({super.key, this.userType = '직장인'});

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  List<Reminder> _userItems = [];   // reminders 테이블 (record + custom)
  Map<String, bool> _sysSettings = {};
  bool _loading = true;
  bool _canExact = true;
  bool _master = true; // 전체 알림 마스터 (꺼지면 모든 예약 정지)

  @override
  void initState() {
    super.initState();
    _load();
    _prepNotifications();
  }

  Future<void> _prepNotifications() async {
    if (kIsWeb) return;
    await notificationHelper.requestPermissions();
    final ok = await notificationHelper.canScheduleExact();
    if (mounted) setState(() => _canExact = ok);
  }

  /// 즉시 알림 — 권한·채널 확인용(예약 경로는 검증 못 함).
  Future<void> _fireNow() async {
    await notificationHelper.showImmediateNotification(
      id: 9999,
      title: '세끌 테스트 알림',
      body: '이 알림이 보이면 알림 권한은 정상이에요.',
    );
    _snack('즉시 알림을 보냈어요. 상단 알림을 확인하세요.');
  }

  /// 1분 뒤 예약 알림 — 실제 예약(zonedSchedule) 경로를 검증한다.
  /// 이게 안 오면 정확 알람 권한/배터리 최적화 문제, 오면 예약 경로는 정상.
  Future<void> _scheduleTest() async {
    final when = DateTime.now().add(const Duration(minutes: 1));
    await notificationHelper.scheduleAtDate(
      id: 9998,
      title: '세끌 예약 테스트',
      body: '1분 예약 알림이 도착했어요. 예약 경로가 정상이에요.',
      when: when,
    );
    final pending = await notificationHelper.pendingCount();
    final exact = await notificationHelper.canScheduleExact();
    _snack('1분 뒤로 예약했어요 (대기 $pending건, 정확알람 ${exact ? "켜짐" : "꺼짐"}). 화면 끄고 기다려보세요.');
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _load() async {
    final items = await customReminderService.list();
    final settings = await dbService.getReminderSettings();
    if (!mounted) return;
    setState(() {
      _userItems = items;
      _sysSettings = settings;
      _master = settings['master'] ?? true;
      _loading = false;
    });
  }

  /// 마스터 OFF에서 다시 켜기 — 영속화 + 시스템·기록 재예약.
  Future<void> _enableMaster() async {
    await dbService.setReminderSetting('master', true);
    if (!kIsWeb) {
      final profile = await dbService.getProfile();
      final payDay = (profile?['pay_day'] as int? ?? 25);
      await notificationHelper.requestPermissions();
      await ReminderScheduler.scheduleAll(payDay: payDay, userType: widget.userType);
    }
    await _load();
  }

  bool _sysOn(String key) => _sysSettings[key] ?? true; // 없으면 ON

  Future<void> _toggleSystem(SystemReminder s, bool v) async {
    await dbService.setReminderSetting(s.key, v);
    // 기한형은 즉시 (재)예약/취소 반영. 이벤트형은 발생 시점에 설정을 읽음.
    if (s.category == SysCategory.deadline) {
      await ReminderScheduler.scheduleTaxSeason(widget.userType);
    }
    await _load();
  }

  Future<void> _openForm({Reminder? existing}) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ReminderFormScreen(existing: existing)));
    if (changed == true) await _load();
  }

  List<Reminder> get _records => _userItems.where((r) => r.kind == 'record').toList();
  List<Reminder> get _customs => _userItems.where((r) => r.kind != 'record').toList();

  String _userSubtitle(Reminder r) {
    final t = '${r.notifyHour.toString().padLeft(2, '0')}:${r.notifyMinute.toString().padLeft(2, '0')}';
    switch (r.frequency) {
      case ReminderFrequency.once:
        return '${r.notifyDate.year}년 ${r.notifyDate.month}월 ${r.notifyDate.day}일 · $t';
      case ReminderFrequency.daily:
        return '매일 · $t';
      case ReminderFrequency.weekly:
        final wd = kWeekdayLabels[((r.weekday ?? r.notifyDate.weekday) - 1) % 7];
        return '매주 $wd요일 · $t';
      case ReminderFrequency.monthly:
        return '매월 ${r.notifyDate.day}일 · $t';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final sys = systemRemindersFor(widget.userType);
    final deadlines = sys.where((s) => s.category == SysCategory.deadline).toList();
    final moments = sys.where((s) => s.category == SysCategory.moment).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!kIsWeb) ...[
            TextButton(
              onPressed: _fireNow,
              child: Text('지금', style: AppTheme.sans(13, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: _scheduleTest,
              child: Text('1분뒤', style: AppTheme.sans(13, AppTheme.accentColor(context), weight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
                children: [
                  Text('리마인더'.toUpperCase(), style: AppTheme.label(context)),
                  const SizedBox(height: 12),
                  Text('챙길 알림', style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
                  const SizedBox(height: 10),
                  Text('세무 일정은 앱이 챙기고, 가계부 기록·개인 일정은 직접 켜고 끌 수 있어요.',
                      style: AppTheme.sans(13.5, sub, height: 1.55)),
                  const SizedBox(height: 18),

                  if (!_master) ...[
                    _masterOffBanner(),
                    const SizedBox(height: 18),
                  ] else if (!_canExact) ...[
                    _exactAlarmWarning(),
                    const SizedBox(height: 18),
                  ],

                  // ── 작성 (기록 시드) ──
                  _section('작성', _records.isEmpty
                      ? [_muted('급여일에 가계부 기록 알림을 보내드려요.')]
                      : _records.map(_userRow).toList()),

                  // ── 기한 (시스템·토글) ──
                  if (deadlines.isNotEmpty)
                    _section('기한', deadlines.map(_systemRow).toList()),

                  // ── 맞춤 (이벤트·토글) ──
                  if (moments.isNotEmpty)
                    _section('맞춤', moments.map(_systemRow).toList()),

                  // ── 내가 만든 (CRUD) ──
                  _section('내가 만든', _customs.isEmpty
                      ? [_muted('월세 이체·건강검진처럼 잊지 않을 일을 직접 만들어요.')]
                      : _customs.map(_userRow).toList()),
                  const SizedBox(height: 10),
                  _addButton(),
                ],
              ),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        AppTheme.hairline(context),
        for (final r in rows) ...[
          r,
          AppTheme.hairline(context),
        ],
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _muted(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(t, style: AppTheme.sans(12.5, AppTheme.inkTertiary(context), height: 1.45)),
      );

  /// 사용자 항목(기록·내가 만든) — 탭하면 수정, 스위치로 켜고 끄기.
  Widget _userRow(Reminder r) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: () => _openForm(existing: r),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(15, r.enabled ? ink : tert, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_userSubtitle(r), style: AppTheme.sans(12.5, tert)),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
      ),
    );
  }

  /// 시스템 항목(기한·맞춤) — 토글만. 탭 수정 없음.
  Widget _systemRow(SystemReminder s) {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final on = _sysOn(s.key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(15, on ? ink : tert, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(s.scheduleLabel, style: AppTheme.sans(12.5, tert)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: on,
            activeColor: accent,
            onChanged: kIsWeb ? null : (v) => _toggleSystem(s, v),
          ),
        ],
      ),
    );
  }

  /// 마스터(전체 알림)가 꺼져 있을 때 — 아래 설정들은 유지되지만 아무 알림도 안 온다.
  Widget _masterOffBanner() {
    final ink = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.lineStrong(context)),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Icon(Icons.notifications_off_rounded, size: 18, color: AppTheme.inkSecondary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text('전체 알림이 꺼져 있어요. 아래 설정은 그대로지만 지금은 아무 알림도 오지 않아요.',
                style: AppTheme.sans(12.5, ink, weight: FontWeight.w600, height: 1.45)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enableMaster,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text('켜기', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exactAlarmWarning() {
    final danger = AppTheme.colorDanger;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: danger.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '정확한 알람 권한이 꺼져 있어요. 설정 → 앱 → 세끌 → "알람 및 리마인더"를 허용하면 제시간에 울려요.',
              style: AppTheme.sans(12.5, AppTheme.inkSecondary(context), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton() {
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: () => _openForm(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppTheme.ink(context), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, size: 18, color: bg),
          const SizedBox(width: 6),
          Text('알림 추가', style: AppTheme.sans(15.5, bg, weight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
