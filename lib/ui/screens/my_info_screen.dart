import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/notifications/reminder_scheduler.dart';
import 'profile_input_screen.dart';

/// 내 정보 — 하단 탭 허브. 정확한 절세 계산의 출발점이라 가장 앞에 둔다.
/// 프로필 완성도 + 핵심 입력값 요약 + 작성/수정 진입.
/// 설정(알림·다크모드·백업 등)은 홈 우상단 톱니(SettingsScreen)에서 관리.
class MyInfoScreen extends StatefulWidget {
  final String userType;

  /// 프로필이 저장되면 홈 대시보드를 다시 읽도록 알린다.
  final VoidCallback onProfileChanged;

  const MyInfoScreen({
    super.key,
    required this.userType,
    required this.onProfileChanged,
  });

  @override
  State<MyInfoScreen> createState() => _MyInfoScreenState();
}

class _MyInfoScreenState extends State<MyInfoScreen> {
  final _fmt = NumberFormat('#,###');

  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await dbService.getProfile();
    if (!mounted) return;
    setState(() {
      _profile = p;
      _loading = false;
    });
  }

  // ── 프로필 완성도 ───────────────────────────────────────────────
  /// 절세 진단에 직접 쓰이는 핵심 입력값들이 채워졌는지로 완성도를 읽는다.
  /// 빈 항목이 곧 "진단이 부정확해지는 이유"라서 그대로 안내에 쓴다.
  List<({String label, bool filled})> get _checklist {
    final p = _profile ?? const {};
    double d(String k) => (p[k] as num?)?.toDouble() ?? 0.0;
    int i(String k) => (p[k] as int?) ?? 0;
    return [
      (label: '예상 연봉', filled: d('gross_income') > 0),
      (label: '나이', filled: i('age') > 0),
      (label: '부양가족', filled: p.containsKey('dependents')),
      (label: '거주 형태', filled: p.containsKey('is_monthly_rent')),
      (label: '급여일', filled: i('pay_day') > 0),
    ];
  }

  int get _filledCount => _checklist.where((e) => e.filled).length;
  double get _completeness => _checklist.isEmpty ? 0 : _filledCount / _checklist.length;

  Future<void> _openProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileInputScreen(userType: widget.userType)),
    );
    if (result == true) {
      await _load();
      widget.onProfileChanged();
    }
  }

  Future<void> _openPayDayPicker() async {
    final current = (_profile?['pay_day'] as int?) ?? 0;
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => _PayDayDialog(current: current),
    );
    if (picked == null || picked == current) return;
    await _savePayDay(picked);
  }

  Future<void> _savePayDay(int day) async {
    final updated = Map<String, dynamic>.from(_profile ?? {});
    updated['pay_day'] = day;
    await dbService.saveProfile(updated);
    if (!mounted) return;
    setState(() => _profile = updated);
    widget.onProfileChanged();
    if (!kIsWeb) {
      await ReminderScheduler.scheduleAll(payDay: day, userType: widget.userType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  Text('내 정보', style: AppTheme.serif(28, ink, spacing: -0.5)),
                  const SizedBox(height: 10),
                  Text('정확한 절세 계산은 여기서 시작해요. 입력할수록 진단과 신고 준비가 정밀해져요.',
                      style: AppTheme.sans(14, sub, height: 1.55)),
                  const SizedBox(height: 24),

                  _profileBlock(ink, sub),
                ],
              ),
      ),
    );
  }

  /// 프로필 완성도 블록 — 도면 시트 메타포(측정 스케일 + 항목 체크).
  Widget _profileBlock(Color ink, Color sub) {
    final accent = AppTheme.accentColor(context);
    final done = _filledCount == _checklist.length;
    final pct = (_completeness * 100).round();
    final gross = (_profile?['gross_income'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line(context), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.userType, style: AppTheme.serif(22, ink, spacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(gross > 0 ? '예상 연봉 ${_fmt.format(gross.toInt())}원' : '예상 연봉 미설정',
                        style: AppTheme.sans(13, sub)),
                  ],
                ),
              ),
              Text('$pct%',
                  style: AppTheme.serif(28, done ? AppTheme.colorSuccess : accent, spacing: -1, height: 1.0)),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: _completeness,
            minHeight: 3,
            backgroundColor: AppTheme.line(context),
            valueColor: AlwaysStoppedAnimation<Color>(done ? AppTheme.colorSuccess : accent),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _checklist.map(_checkChip).toList(),
          ),
          const SizedBox(height: 14),
          AppTheme.hairline(context),
          _payDayRow(ink, sub, accent),
          AppTheme.hairline(context),
          GestureDetector(
            onTap: _openProfile,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Icon(done ? Icons.check_circle_outline : Icons.edit_outlined, size: 18, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(done ? '프로필 수정하기' : '빈 항목 채우러 가기',
                      style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.inkTertiary(context)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payDayRow(Color ink, Color sub, Color accent) {
    final day = (_profile?['pay_day'] as int?) ?? 0;
    final isSet = day > 0;
    return GestureDetector(
      onTap: _openPayDayPicker,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 18, color: isSet ? sub : accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('급여일',
                  style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 2),
              Text(isSet ? '매월 $day일 지급' : '설정되지 않았어요 — 급여일 알림에 쓰여요',
                  style: AppTheme.sans(12, isSet ? sub : accent)),
            ]),
          ),
          Text(isSet ? '$day일' : '설정',
              style: AppTheme.sans(15, isSet ? ink : accent, weight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.inkTertiary(context)),
        ]),
      ),
    );
  }

  Widget _checkChip(({String label, bool filled}) e) {
    final c = e.filled ? AppTheme.inkSecondary(context) : AppTheme.accentColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: e.filled ? AppTheme.line(context) : AppTheme.accentColor(context), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(e.filled ? Icons.check_rounded : Icons.add_rounded, size: 13, color: c),
        const SizedBox(width: 5),
        Text(e.label, style: AppTheme.sans(12, c, weight: FontWeight.w500)),
      ]),
    );
  }

}

/// 1~31 날짜 그리드 선택 다이얼로그.
class _PayDayDialog extends StatefulWidget {
  final int current;
  const _PayDayDialog({required this.current});

  @override
  State<_PayDayDialog> createState() => _PayDayDialogState();
}

class _PayDayDialogState extends State<_PayDayDialog> {
  late int _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    final line = AppTheme.line(context);

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('급여일 선택',
            style: AppTheme.serif(17, ink, weight: FontWeight.w400, spacing: -0.3)),
        const SizedBox(height: 4),
        Text('매월 몇 일에 급여가 지급되나요?',
            style: AppTheme.sans(12, sub, height: 1.4)),
      ]),
      content: SizedBox(
        width: 280,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemCount: 31,
          itemBuilder: (ctx, i) {
            final day = i + 1;
            final isSelected = day == _selected;
            return GestureDetector(
              onTap: () => setState(() => _selected = day),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? accent : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? accent : line,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '$day',
                  style: AppTheme.sans(
                    13,
                    isSelected ? Colors.white : ink,
                    weight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소', style: AppTheme.sans(14, sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('저장', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
        ),
      ],
    );
  }
}
