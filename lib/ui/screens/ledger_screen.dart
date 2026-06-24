import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/expense_item.dart';

const _creditColor  = Color(0xFFB8D4F8);
const _debitColor   = Color(0xFFAAE8CC);
const _otherColor   = Color(0xFFFFE0A8);
const _creditDot    = Color(0xFF3B7DD8);
const _debitDot     = Color(0xFF2BA872);
const _otherDot     = Color(0xFFB87800);

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month;

  // 이달의 raw 항목 (범위 전개 없이 원본 그대로)
  List<ExpenseItem> _items = [];
  final _fmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await dbService.getExpenses();
    final filtered = all.where((e) =>
        e.date.year == _year && e.date.month == _month).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) setState(() => _items = filtered);
  }

  Future<void> _delete(String id) async {
    await dbService.deleteExpense(id);
    await _load();
  }

  // ─── 합계 계산 ────────────────────────────────────────────────

  int get _creditTotal => _items
      .where((e) => e.category == '신용카드')
      .fold(0, (s, e) => s + e.amount);

  int get _debitTotal => _items
      .where((e) => e.category == '체크+현금')
      .fold(0, (s, e) => s + e.amount);

  int get _otherTotal => _items
      .where((e) => e.category == '기타')
      .fold(0, (s, e) => s + e.amount);

  int get _grandTotal => _creditTotal + _debitTotal + _otherTotal;

  // ─── 날짜별 그룹 ───────────────────────────────────────────────

  Map<String, List<ExpenseItem>> get _grouped {
    final map = <String, List<ExpenseItem>>{};
    for (final e in _items) {
      final key = _dayKey(e.date);
      (map[key] ??= []).add(e);
    }
    return map;
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _dayLabel(String key) {
    final d = DateTime.parse(key);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일 (${weekdays[d.weekday - 1]})';
  }

  // ─── build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor  = Theme.of(context).textTheme.labelMedium!.color!;
    final bgColor   = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;

    final grouped = _grouped;
    final dateKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('가계부', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMonthNav(textColor, subColor),
            _buildSummaryCard(textColor, subColor, cardColor),
            if (_items.isEmpty)
              Expanded(child: _buildEmpty(subColor))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: dateKeys.length,
                  itemBuilder: (context, i) {
                    final key = dateKeys[i];
                    final dayItems = grouped[key]!;
                    final dayTotal = dayItems.fold(0, (s, e) => s + e.amount);
                    return _buildDayGroup(key, dayItems, dayTotal, textColor, subColor, cardColor, bgColor);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNav(Color textColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: textColor, size: 28),
            onPressed: () {
              setState(() {
                if (_month == 1) { _year--; _month = 12; } else _month--;
              });
              _load();
            },
          ),
          Text('$_year년 $_month월', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: textColor, size: 28),
            onPressed: () {
              setState(() {
                if (_month == 12) { _year++; _month = 1; } else _month++;
              });
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Color textColor, Color subColor, Color cardColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('월 합계', style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '${_fmt.format(_grandTotal)}원',
            style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          if (_grandTotal > 0) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (_creditTotal > 0) _summaryChip('신용카드', _creditTotal, _creditDot, subColor),
              if (_creditTotal > 0 && _debitTotal > 0) const SizedBox(width: 8),
              if (_debitTotal > 0) _summaryChip('체크+현금', _debitTotal, _debitDot, subColor),
              if ((_creditTotal > 0 || _debitTotal > 0) && _otherTotal > 0) const SizedBox(width: 8),
              if (_otherTotal > 0) _summaryChip('기타', _otherTotal, _otherDot, subColor),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int amount, Color dot, Color subColor) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$label ${_fmt.format(amount)}원', style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildDayGroup(String key, List<ExpenseItem> items, int dayTotal,
      Color textColor, Color subColor, Color cardColor, Color bgColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_dayLabel(key), style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w700)),
              Text('${_fmt.format(dayTotal)}원', style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _buildItemTile(item, textColor, subColor, bgColor),
                  if (i < items.length - 1)
                    Divider(height: 1, color: bgColor, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(ExpenseItem item, Color textColor, Color subColor, Color bgColor) {
    final catColor = item.category == '신용카드' ? _creditColor
        : item.category == '체크+현금' ? _debitColor
        : _otherColor;
    final dotColor = item.category == '신용카드' ? _creditDot
        : item.category == '체크+현금' ? _debitDot
        : _otherDot;
    final hasRange = item.endDate != null;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('항목 삭제', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            content: Text('이 지출 항목을 삭제할까요?', style: TextStyle(color: subColor)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소', style: TextStyle(color: subColor))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _delete(item.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(item.category, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    hasRange ? item.content : item.content,
                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${_fmt.format(item.amount)}원', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Color subColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, color: subColor.withOpacity(0.3), size: 56),
          const SizedBox(height: 12),
          Text('이 달엔 지출 기록이 없어요', style: TextStyle(color: subColor, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
