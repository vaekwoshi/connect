import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/expense_item.dart';
import '../../core/data/income_entry.dart';
import '../../core/data/kr_holidays.dart';
import '../theme/app_theme.dart';


// ── 항목 색상 ──
const _incomeColor = Color(0xFF2FA37A);
const _creditColor = Color(0xFF3B7DD8);
const _debitColor  = Color(0xFFD69A3A);
const _otherColor  = Color(0xFF8E8B85);

const _catCredit = '신용카드';
const _catDebit  = '체크+현금';
const _catOther  = '기타';

class ExpenseCalendarScreen extends StatefulWidget {
  /// 진입 맥락 — 하단 탭 '소득'/'지출'에서 들어올 때 제목·강조를 구분.
  /// 'income' = 소득 기록, 'expense' = 지출 기록, null = 가계부(통합).
  final String? initialFocus;

  const ExpenseCalendarScreen({super.key, this.initialFocus});

  @override
  State<ExpenseCalendarScreen> createState() => _ExpenseCalendarScreenState();
}

class _ExpenseCalendarScreenState extends State<ExpenseCalendarScreen> {
  int _year  = DateTime.now().year;
  int _month = DateTime.now().month;

  Map<String, List<ExpenseItem>> _expensesByDay = {};
  Map<String, List<IncomeEntry>>  _incomesByDay = {};
  Map<String, int> _dayBatchId    = {}; // dateKey → batch 타임스탬프(묶음 선택용)

  final Set<DateTime> _selected = {};
  bool _isDragging = false;
  DateTime? _dragStart;
  DateTime? _dragCurrent;

  final Map<String, GlobalKey> _cellKeys = {};

  final _incomeCtrl = TextEditingController();
  String _incomeType = '급여'; // '급여'(근로소득) | '기타'(기타 수익)
  String _userType = '직장인'; // 직장인 / N잡러 / 프리랜서 — 기타수익 토글 노출 판단
  final _creditCtrl = TextEditingController();
  final _debitCtrl  = TextEditingController();
  final _otherCtrl  = TextEditingController();

  final _fmt = NumberFormat('#,###');
  static const double _cellH = 62.0;

  int get _daysInMonth {
    final next = _month == 12 ? DateTime(_year + 1, 1, 1) : DateTime(_year, _month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  int get _firstOffset => DateTime(_year, _month, 1).weekday - 1;

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _creditCtrl.dispose();
    _debitCtrl.dispose();
    _otherCtrl.dispose();
    super.dispose();
  }

  // ── 데이터 로드 ──────────────────────────────────────────────────

  Future<void> _load() async {
    final profile = await dbService.getProfile();
    final loadedType = (profile?['user_type'] as String?) ?? '직장인';
    final allExpenses = await dbService.getExpenses();
    final allIncome   = await dbService.getIncomeEntriesForMonth(_year, _month);

    final expMap = <String, List<ExpenseItem>>{};
    for (final e in allExpenses) {
      final end = e.endDate ?? e.date;
      var d = DateTime(e.date.year, e.date.month, e.date.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!d.isAfter(endDay)) {
        if (d.year == _year && d.month == _month) {
          (expMap[_key(d)] ??= []).add(e);
        }
        d = d.add(const Duration(days: 1));
      }
    }

    final incMap = <String, List<IncomeEntry>>{};
    for (final e in allIncome) {
      final end = e.endDate ?? e.date;
      var d = DateTime(e.date.year, e.date.month, e.date.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!d.isAfter(endDay)) {
        if (d.year == _year && d.month == _month) {
          (incMap[_key(d)] ??= []).add(e);
        }
        d = d.add(const Duration(days: 1));
      }
    }

    final dayBatch = <String, int>{};
    void absorb(String key, String id) {
      final b = _batchOf(id);
      if (b > (dayBatch[key] ?? -1)) dayBatch[key] = b;
    }
    expMap.forEach((k, list) { for (final e in list) { absorb(k, e.id); } });
    incMap.forEach((k, list) { for (final e in list) { absorb(k, e.id); } });

    if (mounted) {
      setState(() {
        _userType = loadedType;
        if (_userType == '직장인') _incomeType = '급여'; // 직장인은 급여만
        _expensesByDay = expMap;
        _incomesByDay  = incMap;
        _dayBatchId    = dayBatch;
      });
    }
  }

  int _batchOf(String id) {
    if (id.startsWith('b')) {
      final us = id.indexOf('_');
      if (us > 1) return int.tryParse(id.substring(1, us)) ?? 0;
    }
    return 0;
  }

  // ── 월 합계 ──────────────────────────────────────────────────────

  int get _monthIncomeTotal =>
      _incomesByDay.values.expand((l) => l).toSet().fold(0, (s, e) => s + e.amount);

  int get _monthExpenseTotal =>
      _expensesByDay.values.expand((l) => l).toSet().fold(0, (s, e) => s + e.amount);

  // ── 날짜별 합계 ──────────────────────────────────────────────────

  int _incomeOf(String key) =>
      (_incomesByDay[key] ?? const []).fold(0, (s, e) => s + e.amount);

  int _catOf(String key, String cat) => (_expensesByDay[key] ?? const [])
      .toSet()
      .where((e) => e.category == cat)
      .fold(0, (s, e) => s + e.amount);

  bool _hasData(String key) =>
      (_incomesByDay[key]?.isNotEmpty ?? false) ||
      (_expensesByDay[key]?.isNotEmpty ?? false);

  // ── 선택 ─────────────────────────────────────────────────────────

  /// 같은 묶음(배치 = 같은 배경색)으로 입력된 날짜들을 한 번에 선택.
  /// 데이터 없는 날은 그 날 단독.
  Set<DateTime> _groupDatesFor(DateTime date) {
    final batch = _dayBatchId[_key(date)];
    if (batch == null) return {date};
    final out = <DateTime>{};
    _dayBatchId.forEach((k, b) {
      if (b == batch) out.add(DateTime.parse(k));
    });
    return out.isEmpty ? {date} : out;
  }

  void _toggleSingle(DateTime date) {
    final group = _groupDatesFor(date);
    setState(() {
      final alreadySelected =
          _selected.length == group.length && group.every(_selected.contains);
      if (alreadySelected) {
        _selected.clear();
        _clearForm();
      } else {
        _selected..clear()..addAll(group);
        _prefillFromDate(group.reduce((a, b) => a.isBefore(b) ? a : b));
      }
    });
  }

  /// 그 날 기록된 소득의 유형(첫 항목 기준). 없으면 근로소득(급여) 기본.
  String _incomeTypeOf(String key) {
    final list = _incomesByDay[key];
    if (list == null || list.isEmpty) return '급여';
    return list.first.incomeType;
  }

  /// 대표 날짜(가장 이른) 기준으로 폼 prefill — 묶음은 같은 금액의 한 건.
  void _prefillFromDate(DateTime date) {
    final key = _key(date);
    final inc = _incomeOf(key);
    final cr = _catOf(key, _catCredit);
    final db = _catOf(key, _catDebit);
    final ot = _catOf(key, _catOther);
    _incomeType = _incomeTypeOf(key);
    _incomeCtrl.text = inc > 0 ? _fmt.format(inc) : '';
    _creditCtrl.text = cr > 0 ? _fmt.format(cr) : '';
    _debitCtrl.text  = db > 0 ? _fmt.format(db) : '';
    _otherCtrl.text  = ot > 0 ? _fmt.format(ot) : '';
  }

  void _prefillForm() {
    if (_selected.length == 1) {
      final key = _key(_selected.first);
      final inc = _incomeOf(key);
      _incomeType = _incomeTypeOf(key);
      _incomeCtrl.text = inc > 0 ? _fmt.format(inc) : '';
      final cr = _catOf(key, _catCredit);
      final db = _catOf(key, _catDebit);
      final ot = _catOf(key, _catOther);
      _creditCtrl.text = cr > 0 ? _fmt.format(cr) : '';
      _debitCtrl.text  = db > 0 ? _fmt.format(db) : '';
      _otherCtrl.text  = ot > 0 ? _fmt.format(ot) : '';
    } else {
      _clearForm();
    }
  }

  /// 수익 유형 토글 — 근로소득(급여) vs 기타 수익(기타).
  /// 수익 입력 필드의 레이블 폭(58px)에 맞춰 정렬.
  /// 직장인 — 기타수익 입력란 대신 종합과세 기준 안내.
  Widget _employeeOtherIncomeNotice() {
    final sub = AppTheme.inkSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(left: 58),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 13, color: sub),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '직장인은 급여만 기록해요. 근로 외 기타소득이 연 300만 원을 넘으면 '
              '종합과세 대상 — N잡러로 전환해 따로 기록하세요.',
              style: AppTheme.sans(11.5, sub, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomeTypeToggle() {
    final sub = AppTheme.inkSecondary(context);
    // 소득유형 분류 안내 — 근로 vs 사업/기타(간이지급명세서 구분 기준).
    final hint = _incomeType == '급여'
        ? '근로소득 — 회사 월급·상여. 연말정산으로 정산돼요.'
        : '기타 수익 — 프리랜서 3.3%·강연료 등. 5월 종합소득세에 합산돼요.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 58,
              child: Text('구분', style: AppTheme.sans(13, sub, weight: FontWeight.w600)),
            ),
            _incomeTypeChip('근로소득', '급여'),
            const SizedBox(width: 8),
            _incomeTypeChip('기타 수익', '기타'),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 58),
          child: Text(hint, style: AppTheme.sans(11.5, sub, height: 1.4)),
        ),
      ],
    );
  }

  Widget _incomeTypeChip(String label, String type) {
    final selected = _incomeType == type;
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return GestureDetector(
      onTap: () => setState(() => _incomeType = type),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _incomeColor.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? _incomeColor : AppTheme.line(context),
            width: selected ? 1.4 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(12.5, selected ? ink : sub,
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  void _clearForm() {
    _incomeType = '급여';
    _incomeCtrl.clear();
    _creditCtrl.clear();
    _debitCtrl.clear();
    _otherCtrl.clear();
  }

  void _deselect() {
    setState(() {
      _selected.clear();
      _clearForm();
    });
  }

  // ── 드래그 히트테스트 ────────────────────────────────────────────

  DateTime? _dateAtGlobal(Offset global) {
    for (final entry in _cellKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = topLeft & box.size;
      if (rect.contains(global)) return DateTime.parse(entry.key);
    }
    return null;
  }

  Set<DateTime> _rangeBetween(DateTime a, DateTime b) {
    final start = a.isBefore(b) ? a : b;
    final end   = a.isBefore(b) ? b : a;
    final out = <DateTime>{};
    var d = start;
    while (!d.isAfter(end)) { out.add(d); d = d.add(const Duration(days: 1)); }
    return out;
  }

  // ── 저장 / 삭제 ──────────────────────────────────────────────────

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    final inc = int.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
    final cr  = int.tryParse(_creditCtrl.text.replaceAll(',', '')) ?? 0;
    final db  = int.tryParse(_debitCtrl.text.replaceAll(',', '')) ?? 0;
    final ot  = int.tryParse(_otherCtrl.text.replaceAll(',', '')) ?? 0;

    final sorted = _selected.toList()..sort();
    final first = sorted.first;
    final last  = sorted.last;
    final isRange = sorted.length > 1;
    final endDate = isRange ? last : null;

    final removedInc = <String>{};
    final removedExp = <String>{};
    for (final date in _selected) {
      final key = _key(date);
      for (final e in (_incomesByDay[key] ?? const [])) {
        if (removedInc.add(e.id)) {
          await dbService.deleteIncomeEntry(e.id, e.date.year, e.date.month);
        }
      }
      for (final e in (_expensesByDay[key] ?? const [])) {
        if (removedExp.add(e.id)) {
          await dbService.deleteExpense(e.id);
        }
      }
    }

    final batch = DateTime.now().microsecondsSinceEpoch;
    final prefix = 'b${batch}_${_key(first)}';
    if (inc > 0) {
      await dbService.insertIncomeEntry(IncomeEntry(
        id: '${prefix}_inc', date: first, endDate: endDate, amount: inc, memo: '', incomeType: _incomeType));
    }
    if (cr > 0) {
      await dbService.insertExpense(ExpenseItem(
        id: '${prefix}_cr', date: first, endDate: endDate, amount: cr, content: _catCredit, category: _catCredit));
    }
    if (db > 0) {
      await dbService.insertExpense(ExpenseItem(
        id: '${prefix}_db', date: first, endDate: endDate, amount: db, content: _catDebit, category: _catDebit));
    }
    if (ot > 0) {
      await dbService.insertExpense(ExpenseItem(
        id: '${prefix}_ot', date: first, endDate: endDate, amount: ot, content: _catOther, category: _catOther));
    }

    await _load();
    _deselect();
  }

  Future<void> _deleteSelected() async {
    for (final date in _selected) {
      final key = _key(date);
      for (final e in (_incomesByDay[key] ?? const [])) {
        await dbService.deleteIncomeEntry(e.id, date.year, date.month);
      }
      for (final e in (_expensesByDay[key] ?? const []).toSet()) {
        await dbService.deleteExpense(e.id);
      }
    }
    await _load();
    _deselect();
  }

  // ── build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final bg  = AppTheme.backgroundColor(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text(
          widget.initialFocus == 'income'
              ? '소득 기록'
              : widget.initialFocus == 'expense'
                  ? '지출 기록'
                  : '가계부',
          style: AppTheme.serif(20, ink),
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _deselect,
              child: Text('취소', style: AppTheme.sans(14, AppTheme.accentColor(context))),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildMonthNav(ink),
            AppTheme.hairline(context),
            _buildSummaryBar(sub),
            _buildLegend(),
            AppTheme.hairline(context),
            _buildDowRow(),
            AppTheme.hairline(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: _buildCalendar(ink, sub),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 색 점 범례 — 셀의 색이 무엇을 뜻하는지 안내
  Widget _buildLegend() {
    Widget item(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: AppTheme.sans(10.5, AppTheme.inkSecondary(context), weight: FontWeight.w500)),
        ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Wrap(spacing: 14, runSpacing: 6, children: [
        item(_incomeColor, '수익'),
        item(_creditColor, '신용카드'),
        item(_debitColor, '체크/현금'),
        item(_otherColor, '기타'),
      ]),
    );
  }

  Widget _buildMonthNav(Color ink) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: ink, size: 26),
            onPressed: () {
              setState(() {
                if (_month == 1) { _year--; _month = 12; } else { _month--; }
                _selected.clear(); _clearForm();
              });
              _load();
            },
          ),
          Text('$_year. $_month', style: AppTheme.sans(18, ink, weight: FontWeight.w700)),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: ink, size: 26),
            onPressed: () {
              setState(() {
                if (_month == 12) { _year++; _month = 1; } else { _month++; }
                _selected.clear(); _clearForm();
              });
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(Color sub) {
    final balance = _monthIncomeTotal - _monthExpenseTotal;
    final ink = AppTheme.ink(context);
    final balanceColor = balance >= 0 ? ink : AppTheme.colorDanger;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _summaryItem('수입', _monthIncomeTotal, ink)),
          Container(width: 1, height: 32, color: AppTheme.line(context)),
          Expanded(child: _summaryItem('지출', _monthExpenseTotal, AppTheme.colorDanger)),
          Container(width: 1, height: 32, color: AppTheme.line(context)),
          Expanded(child: _summaryItem('잔액', balance.abs(), balanceColor,
              prefix: balance < 0 ? '-' : '')),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int amount, Color color, {String prefix = ''}) {
    return Column(
      children: [
        Text(label, style: AppTheme.label(context)),
        const SizedBox(height: 4),
        Text('$prefix${_fmt.format(amount)}원',
            style: AppTheme.sans(13, color, weight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildDowRow() {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return SizedBox(
      height: 28,
      child: Row(
        children: List.generate(7, (i) {
          final isSun = i == 6;
          final isSat = i == 5;
          return Expanded(
            child: Center(
              child: Text(labels[i],
                  style: AppTheme.label(context,
                      color: isSun
                          ? AppTheme.colorDanger
                          : isSat
                              ? AppTheme.accentColor(context)
                              : null)),
            ),
          );
        }),
      ),
    );
  }

  // ── 달력 본체 ────────────────────────────────────────────────────

  Widget _buildCalendar(Color ink, Color sub) {
    _cellKeys.clear();

    int? editorRow;
    if (_selected.isNotEmpty && !_isDragging) {
      final maxDate = _selected.reduce((a, b) => a.isAfter(b) ? a : b);
      editorRow = (maxDate.day - 1 + _firstOffset) ~/ 7;
    }

    final rows = <Widget>[];
    for (int row = 0; row < 6; row++) {
      final firstIdx = row * 7 - _firstOffset;
      if (firstIdx >= _daysInMonth) break;

      rows.add(SizedBox(
        height: _cellH,
        child: Row(
          children: List.generate(7, (col) {
            final idx = row * 7 + col - _firstOffset;
            if (idx < 0 || idx >= _daysInMonth) {
              return const Expanded(child: SizedBox());
            }
            return Expanded(child: _buildCell(DateTime(_year, _month, idx + 1), ink, sub));
          }),
        ),
      ));

      if (editorRow == row) {
        rows.add(_buildInlineEditor(ink, sub));
      }
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        final date = _dateAtGlobal(e.position);
        if (date == null) return;
        setState(() {
          _dragStart = date;
          _dragCurrent = date;
          _isDragging = false;
        });
      },
      onPointerMove: (e) {
        if (_dragStart == null) return;
        final date = _dateAtGlobal(e.position);
        if (date == null || date == _dragCurrent) return;
        _dragCurrent = date;
        setState(() {
          _isDragging = true;
          _selected..clear()..addAll(_rangeBetween(_dragStart!, date));
        });
      },
      onPointerUp: (e) {
        if (_dragStart != null && !_isDragging) {
          _toggleSingle(_dragStart!);
        } else if (_isDragging) {
          setState(() => _isDragging = false);
          _prefillForm();
        }
        _dragStart = null;
        _dragCurrent = null;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(children: rows),
      ),
    );
  }

  Widget _buildCell(DateTime date, Color ink, Color sub) {
    final key = _key(date);
    final gkey = _cellKeys[key] = GlobalKey();
    final isSun = date.weekday == DateTime.sunday;
    final isSat = date.weekday == DateTime.saturday;
    final isHoliday = KrHolidays.isHoliday(date);
    final dayColor = (isSun || isHoliday)
        ? AppTheme.colorDanger
        : isSat
            ? AppTheme.accentColor(context)
            : ink;
    final isSelected = _selected.contains(date);
    final isDark = AppTheme.isDark(context);
    final accent = AppTheme.accentColor(context);

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    final income = _incomeOf(key);
    final cr = _catOf(key, _catCredit);
    final db = _catOf(key, _catDebit);
    final ot = _catOf(key, _catOther);

    // 선택 연결 — 드래그 다중선택 시 옅은 배경을 이어 붙인다(테두리 없음).
    final prevDay = date.subtract(const Duration(days: 1));
    final nextDay = date.add(const Duration(days: 1));
    final selConnLeft  = isSelected && _selected.contains(prevDay);
    final selConnRight = isSelected && _selected.contains(nextDay);
    final selBg = accent.withValues(alpha: isDark ? 0.24 : 0.12);

    // 날짜 숫자 — 오늘은 채운 원 안에(흰 글씨), 평소엔 요일색.
    final bool todayPill = isToday && !isSelected;
    final Widget dayNumber = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: todayPill ? BoxDecoration(color: accent, shape: BoxShape.circle) : null,
      child: Text('${date.day}',
          style: AppTheme.sans(13,
              todayPill ? Colors.white : dayColor,
              weight: (isSelected || isToday) ? FontWeight.w800 : FontWeight.w600)),
    );

    return Container(
      key: gkey,
      child: Container(
        margin: EdgeInsets.only(
          left:  selConnLeft  ? 0 : 2,
          right: selConnRight ? 0 : 2,
          top: 2, bottom: 2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? selBg : null,
          borderRadius: BorderRadius.only(
            topLeft:     selConnLeft  ? Radius.zero : const Radius.circular(10),
            bottomLeft:  selConnLeft  ? Radius.zero : const Radius.circular(10),
            topRight:    selConnRight ? Radius.zero : const Radius.circular(10),
            bottomRight: selConnRight ? Radius.zero : const Radius.circular(10),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        child: Column(
          children: [
            dayNumber,
            const SizedBox(height: 3),
            Expanded(
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.start,
                children: [
                  if (income > 0) _catDot(_incomeColor, isDark),
                  if (cr > 0)     _catDot(_creditColor, isDark),
                  if (db > 0)     _catDot(_debitColor,  isDark),
                  if (ot > 0)     _catDot(_otherColor,  isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카테고리 색 점 — 숫자 대신 무슨 항목이 있는지 색으로 표시
  Widget _catDot(Color color, bool isDark) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
    );
  }

  // ── 인라인 에디터 ─────────────────────────────────────────────────

  Widget _buildInlineEditor(Color ink, Color sub) {
    final sorted = _selected.toList()..sort();
    final isRange = sorted.length > 1;
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    final title = isRange
        ? '${sorted.first.month}월 ${sorted.first.day}일 – ${sorted.last.month}월 ${sorted.last.day}일'
        : '${sorted.first.month}월 ${sorted.first.day}일 (${wd[sorted.first.weekday - 1]})';
    final caption = isRange
        ? '${sorted.length}일 기간 — 같은 금액으로 한 건 기록'
        : '이 날의 수입과 지출을 입력하세요';
    final hasExisting = _selected.any((d) => _hasData(_key(d)));

    return Container(
      margin: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.lineStrong(context), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(title,
                    style: AppTheme.serif(17, ink, weight: FontWeight.w400, spacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              GestureDetector(
                onTap: _deselect,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(Icons.close_rounded, size: 18, color: sub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(caption, style: AppTheme.sans(11.5, AppTheme.inkTertiary(context))),
          const SizedBox(height: 14),

          // 입력 필드 — 레이블 고정 너비(58px)로 정렬 일관성
          _BlueprintAmountField(label: '수익',     ctrl: _incomeCtrl, color: _incomeColor, fmt: _fmt),
          const SizedBox(height: 8),
          // 직장인은 급여만 기록 — 기타수익 토글 숨기고 종합과세 기준 안내.
          if (_userType != '직장인')
            _incomeTypeToggle()
          else
            _employeeOtherIncomeNotice(),
          const SizedBox(height: 10),
          _BlueprintAmountField(label: '신용카드', ctrl: _creditCtrl, color: _creditColor, fmt: _fmt),
          const SizedBox(height: 10),
          _BlueprintAmountField(label: '체크/현금', ctrl: _debitCtrl,  color: _debitColor,  fmt: _fmt),
          const SizedBox(height: 10),
          _BlueprintAmountField(label: '기타',     ctrl: _otherCtrl,  color: _otherColor,  fmt: _fmt),
          const SizedBox(height: 14),

          // 버튼
          Row(children: [
            if (hasExisting) ...[
              GestureDetector(
                onTap: _deleteSelected,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.colorDanger, width: 1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('삭제', style: AppTheme.sans(13, AppTheme.colorDanger, weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: GestureDetector(
                onTap: _save,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(hasExisting ? '수정' : '저장',
                      style: AppTheme.sans(14, AppTheme.backgroundColor(context), weight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── 금액 입력 필드 — 레이블 고정 너비 58px, 항목 색으로 포커스 표시 ──
class _BlueprintAmountField extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  final Color color;
  final NumberFormat fmt;

  const _BlueprintAmountField({
    required this.label,
    required this.ctrl,
    required this.color,
    required this.fmt,
  });

  @override
  State<_BlueprintAmountField> createState() => _BlueprintAmountFieldState();
}

class _BlueprintAmountFieldState extends State<_BlueprintAmountField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final focused = _focus.hasFocus;
    final lineColor  = focused ? widget.color : AppTheme.line(context);
    final labelColor = focused ? widget.color : sub;

    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor, width: focused ? 1.6 : 1.0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 58,
            child: Text(widget.label,
                style: AppTheme.sans(13, labelColor, weight: FontWeight.w600)),
          ),
          Expanded(
            child: TextField(
              controller: widget.ctrl,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              cursorColor: widget.color,
              style: AppTheme.sans(18, ink, weight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '0',
                hintStyle: AppTheme.sans(18, AppTheme.inkTertiary(context), weight: FontWeight.w300),
              ),
              onChanged: (v) {
                final n = v.replaceAll(RegExp(r'[^0-9]'), '');
                final f = n.isEmpty ? '' : widget.fmt.format(int.parse(n));
                if (f != widget.ctrl.text) {
                  widget.ctrl.value = TextEditingValue(
                    text: f, selection: TextSelection.collapsed(offset: f.length));
                }
              },
            ),
          ),
          const SizedBox(width: 6),
          Text('원', style: AppTheme.sans(12, sub)),
        ],
      ),
    );
  }
}
