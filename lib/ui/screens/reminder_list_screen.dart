import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/notifications/reminder.dart';
import '../../core/notifications/custom_reminder_service.dart';
import '../../core/security/notification_helper.dart';
import 'reminder_form_screen.dart';

/// 리마인더 — 사용자 직접 생성 알림만.
/// 세금 일정·공제 문턱·예산 알림은 전체탭 > 알림 설정에서 관리.
class ReminderListScreen extends StatefulWidget {
  final String userType;

  /// 하단 탭에 끼워질 때(true)는 leading 숨김.
  final bool embedded;
  const ReminderListScreen(
      {super.key, this.userType = '직장인', this.embedded = false});

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  List<Reminder> _userItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    if (!kIsWeb) notificationHelper.requestPermissions();
  }

  Future<void> _load() async {
    final items = await customReminderService.list();
    if (!mounted) return;
    setState(() {
      _userItems = items;
      _loading = false;
    });
  }

  Future<void> _openForm({Reminder? existing}) async {
    final changed = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => ReminderFormScreen(existing: existing)));
    if (changed == true) await _load();
  }

  List<Reminder> get _records =>
      _userItems.where((r) => r.kind == 'record').toList();
  List<Reminder> get _customs =>
      _userItems.where((r) => r.kind != 'record').toList();

  String _userSubtitle(Reminder r) {
    final t =
        '${r.notifyHour.toString().padLeft(2, '0')}:${r.notifyMinute.toString().padLeft(2, '0')}';
    switch (r.frequency) {
      case ReminderFrequency.once:
        return '${r.notifyDate.year}년 ${r.notifyDate.month}월 ${r.notifyDate.day}일 · $t';
      case ReminderFrequency.daily:
        return '매일 · $t';
      case ReminderFrequency.weekly:
        final wd =
            kWeekdayLabels[((r.weekday ?? r.notifyDate.weekday) - 1) % 7];
        return '매주 $wd요일 · $t';
      case ReminderFrequency.monthly:
        return '매월 ${r.notifyDate.day}일 · $t';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: sub),
                onPressed: () => Navigator.pop(context),
              ),
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
                  Text('챙길 알림',
                      style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
                  const SizedBox(height: 10),
                  Text('직접 만든 알림과 가계부 기록 넛지를 관리해요.',
                      style: AppTheme.sans(14, sub, height: 1.55)),
                  const SizedBox(height: 18),

                  // ── 작성 (기록 시드) ──
                  _section(
                      '작성',
                      _records.isEmpty
                          ? [_muted('급여일에 가계부 기록 알림을 보내드려요.')]
                          : _records.map(_userRow).toList()),

                  // ── 내가 만든 (CRUD) ──
                  _section(
                      '내가 만든',
                      _customs.isEmpty
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
        child: Text(t,
            style: AppTheme.sans(12, AppTheme.inkTertiary(context),
                height: 1.45)),
      );

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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(15, r.enabled ? ink : tert,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_userSubtitle(r), style: AppTheme.sans(12, tert)),
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

  Widget _addButton() {
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: () => _openForm(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppTheme.ink(context),
            borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_rounded, size: 18, color: bg),
          const SizedBox(width: 6),
          Text('알림 추가', style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
