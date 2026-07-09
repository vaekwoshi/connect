import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/data/db_helper.dart';
import '../../core/notifications/reminder_scheduler.dart';
import '../theme/app_theme.dart';
import 'recurring_templates_screen.dart';

/// 월급날 · 카드 결제일 · 고정지출을 한곳에서 관리하는 화면.
/// 가계부 달력 AppBar의 "관리" 아이콘에서 진입 — 셋 다 "가끔 설정해두는" 성격이라
/// 캘린더 위 상시 노출 대신 여기로 모았다.
class PaymentManagementScreen extends StatefulWidget {
  final bool showPayday;

  const PaymentManagementScreen({super.key, required this.showPayday});

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  int _paydayDay = 25;
  List<Map<String, dynamic>> _cardDates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await dbService.getProfile();
    final cards = await dbService.getCardPaymentDates();
    if (!mounted) return;
    setState(() {
      _paydayDay = (profile?['pay_day'] as int? ?? 25).clamp(1, 31);
      _cardDates = cards;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.backgroundColor(context);
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text('결제·고정지출 관리', style: AppTheme.serif(22, ink)),
      ),
      body: _loading
          ? const SizedBox()
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (widget.showPayday) ...[
                    _sectionLabel('월급날', sub),
                    _row(
                      icon: Icons.payments_outlined,
                      label: '월급 $_paydayDay일',
                      ink: ink, sub: sub,
                      onTap: _showPaydayPicker,
                    ),
                    const SizedBox(height: 24),
                  ],
                  _sectionLabel('카드 결제일', sub),
                  for (final card in _cardDates)
                    _row(
                      icon: Icons.credit_card_rounded,
                      label: '${card['name']} ${card['day']}일',
                      ink: ink, sub: sub,
                      onTap: () => _showCardOptions(card),
                    ),
                  GestureDetector(
                    onTap: _showAddCardDialog,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(children: [
                        Icon(Icons.add_rounded, size: 18, color: accent),
                        const SizedBox(width: 10),
                        Text('카드 추가', style: AppTheme.sans(14, accent, weight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('고정지출', sub),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RecurringTemplatesScreen()),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(children: [
                        Icon(Icons.event_repeat_outlined, size: 18, color: ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('고정지출 관리', style: AppTheme.sans(14, ink, weight: FontWeight.w600)),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: sub),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text, Color sub) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: AppTheme.sans(12, sub, weight: FontWeight.w700)),
      );

  Widget _row({
    required IconData icon,
    required String label,
    required Color ink,
    required Color sub,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: sub),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTheme.sans(14, ink, weight: FontWeight.w600))),
          Icon(Icons.chevron_right_rounded, size: 18, color: sub),
        ]),
      ),
    );
  }

  Future<void> _showPaydayPicker() async {
    final ink    = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final bg     = AppTheme.backgroundColor(context);
    final line   = AppTheme.line(context);
    final sub    = AppTheme.inkSecondary(context);

    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int current = _paydayDay;
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: line),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            title: Text('월급날 설정', style: AppTheme.serif(17, ink)),
            content: SizedBox(
              height: 120,
              child: ListWheelScrollView.useDelegate(
                itemExtent: 36,
                onSelectedItemChanged: (i) => setSt(() => current = i + 1),
                controller: FixedExtentScrollController(initialItem: _paydayDay - 1),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: 31,
                  builder: (_, i) => Center(
                    child: Text('${i + 1}일',
                        style: AppTheme.sans(
                            16,
                            i + 1 == current ? ink : AppTheme.inkTertiary(ctx),
                            weight: i + 1 == current
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ),
                ),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 12),
                  child: Text('취소', style: AppTheme.sans(14, sub)),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, current),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                  child: Text('저장',
                      style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
                ),
              ),
            ],
          );
        });
      },
    );

    if (confirmed == null || !mounted) return;
    final profile = await dbService.getProfile() ?? {};
    await dbService.saveProfile({...profile, 'pay_day': confirmed});
    if (mounted) setState(() => _paydayDay = confirmed);
  }

  Future<void> _showAddCardDialog() async {
    final nameCtrl = TextEditingController();
    int selectedDay = 1;
    final ink    = AppTheme.ink(context);
    final accent = AppTheme.accentColor(context);
    final bg     = AppTheme.backgroundColor(context);
    final line   = AppTheme.line(context);
    final sub    = AppTheme.inkSecondary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        int currentDay = selectedDay;
        return StatefulBuilder(builder: (ctx, setSt) {
          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: line),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            title: Text('카드 결제일 추가', style: AppTheme.serif(17, ink)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('카드 이름',
                    style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: AppTheme.sans(15, ink),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '예: 신한카드',
                    hintStyle: AppTheme.sans(15, AppTheme.inkTertiary(ctx)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: UnderlineInputBorder(
                        borderSide: BorderSide(color: line)),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: line)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accent, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('결제일',
                    style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 100,
                  child: ListWheelScrollView.useDelegate(
                    itemExtent: 32,
                    onSelectedItemChanged: (i) =>
                        setSt(() => currentDay = i + 1),
                    controller:
                        FixedExtentScrollController(initialItem: currentDay - 1),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 31,
                      builder: (_, i) => Center(
                        child: Text('${i + 1}일',
                            style: AppTheme.sans(
                                14,
                                i + 1 == currentDay
                                    ? ink
                                    : AppTheme.inkTertiary(ctx),
                                weight: i + 1 == currentDay
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 8, 12),
                  child: Text('취소', style: AppTheme.sans(14, sub)),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  selectedDay = currentDay;
                  Navigator.pop(ctx, true);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                  child: Text('추가',
                      style:
                          AppTheme.sans(14, accent, weight: FontWeight.w700)),
                ),
              ),
            ],
          );
        });
      },
    );

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (confirmed != true || name.isEmpty || !mounted) return;

    await dbService.addCardPaymentDate(name, selectedDay);
    final updated = await dbService.getCardPaymentDates();
    if (!kIsWeb) await ReminderScheduler.scheduleCardPayments(updated);
    if (mounted) setState(() => _cardDates = updated);
  }

  Future<void> _showCardOptions(Map<String, dynamic> card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ink  = AppTheme.ink(ctx);
        final bg   = AppTheme.backgroundColor(ctx);
        final line = AppTheme.line(ctx);
        final sub  = AppTheme.inkSecondary(ctx);
        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: line),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          title: Text('${card['name']} ${card['day']}일',
              style: AppTheme.serif(17, ink)),
          content: GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('삭제',
                  style: AppTheme.sans(15, AppTheme.colorDanger,
                      weight: FontWeight.w600)),
            ),
          ),
          actions: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                child: Text('취소', style: AppTheme.sans(14, sub)),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await dbService.deleteCardPaymentDate(card['id'] as int);
    final updated = await dbService.getCardPaymentDates();
    if (!kIsWeb) await ReminderScheduler.scheduleCardPayments(updated);
    if (mounted) setState(() => _cardDates = updated);
  }
}
