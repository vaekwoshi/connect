import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const PreviewApp());
}

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '세끌 미리보기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F7F5),
        primaryColor: const Color(0xFF1F5AE0),
        fontFamily: 'sans-serif',
      ),
      home: const CalendarPreview(),
    );
  }
}

// ── 팔레트 ──────────────────────────────────────────────────
const _incomeColor = Color(0xFF2FA37A);
const _creditColor = Color(0xFF3B7DD8);
const _debitColor  = Color(0xFFD69A3A);
const _otherColor  = Color(0xFF8E8B85);

const _ink    = Color(0xFF161513);
const _sub    = Color(0xFF5E5C57);
const _terti  = Color(0xFF908D86);
const _line   = Color(0xFFDCD8D0);
const _lineS  = Color(0xFFC7C2B8);
const _bg     = Color(0xFFF8F7F5);
const _surf   = Color(0xFFFFFFFF);
const _accent = Color(0xFF1F5AE0);
const _danger = Color(0xFFD9503F);

// ── 목 데이터 ────────────────────────────────────────────────
final _mockExpenses = <String, Map<String, int>>{
  '2026-06-03': {'신용카드': 45000},
  '2026-06-05': {'체크+현금': 12000},
  '2026-06-07': {'신용카드': 89000, '체크+현금': 15000},
  '2026-06-10': {'기타': 30000},
  '2026-06-11': {'신용카드': 120000},
  '2026-06-14': {'체크+현금': 8500},
  '2026-06-17': {'신용카드': 67000},
  '2026-06-18': {'신용카드': 55000, '기타': 20000},
  '2026-06-21': {'체크+현금': 43000},
  '2026-06-24': {'신용카드': 98000},
  '2026-06-27': {'체크+현금': 18000},
};

final _mockIncome = <String, int>{
  '2026-06-01': 3200000,
};

// ─────────────────────────────────────────────────────────────

class CalendarPreview extends StatefulWidget {
  const CalendarPreview({super.key});

  @override
  State<CalendarPreview> createState() => _CalendarPreviewState();
}

class _CalendarPreviewState extends State<CalendarPreview> {
  final int _year  = 2026;
  final int _month = 6;

  final Set<DateTime> _selected = {};
  bool _isDragging = false;
  DateTime? _dragStart;
  DateTime? _dragCurrent;

  final Map<String, GlobalKey> _cellKeys = {};
  final _fmt = NumberFormat('#,###');

  static const double _cellH = 62.0;

  final _incomeCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();
  final _debitCtrl  = TextEditingController();
  final _otherCtrl  = TextEditingController();

  int get _daysInMonth {
    final next = DateTime(_year, _month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }
  int get _firstOffset => DateTime(_year, _month, 1).weekday - 1;

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  int get _totalIncome => _mockIncome.values.fold(0, (s, v) => s + v);
  int get _totalExpense {
    int sum = 0;
    for (final m in _mockExpenses.values) {
      for (final v in m.values) sum += v;
    }
    return sum;
  }

  Color _expenseBg(DateTime d) {
    final cats = _mockExpenses[_key(d)];
    if (cats == null) return Colors.transparent;
    final c = cats.containsKey('신용카드');
    final b = cats.containsKey('체크+현금');
    final o = cats.containsKey('기타');
    if ((c && b) || (c && o) || (b && o)) return const Color(0xFFE2C8FF);
    if (c) return const Color(0xFFBFD8FF);
    if (b) return const Color(0xFFBFEFD4);
    if (o) return const Color(0xFFFFE3B0);
    return Colors.transparent;
  }

  bool _hasData(String key) =>
      (_mockExpenses[key]?.isNotEmpty ?? false) || _mockIncome.containsKey(key);

  int _incomeOf(String k) => _mockIncome[k] ?? 0;
  int _catOf(String k, String cat) => _mockExpenses[k]?[cat] ?? 0;

  void _toggleSingle(DateTime date) {
    setState(() {
      if (_selected.length == 1 && _selected.contains(date)) {
        _selected.clear();
      } else {
        _selected..clear()..add(date);
        _prefillForm();
      }
    });
  }

  void _prefillForm() {
    if (_selected.length != 1) { _clearForm(); return; }
    final k = _key(_selected.first);
    final inc = _incomeOf(k);
    final cr = _catOf(k, '신용카드');
    final db = _catOf(k, '체크+현금');
    final ot = _catOf(k, '기타');
    _incomeCtrl.text = inc > 0 ? _fmt.format(inc) : '';
    _creditCtrl.text = cr  > 0 ? _fmt.format(cr)  : '';
    _debitCtrl.text  = db  > 0 ? _fmt.format(db)   : '';
    _otherCtrl.text  = ot  > 0 ? _fmt.format(ot)   : '';
  }

  void _clearForm() {
    _incomeCtrl.clear(); _creditCtrl.clear();
    _debitCtrl.clear();  _otherCtrl.clear();
  }

  void _deselect() => setState(() { _selected.clear(); _clearForm(); });

  Set<DateTime> _rangeBetween(DateTime a, DateTime b) {
    final s = a.isBefore(b) ? a : b;
    final e = a.isBefore(b) ? b : a;
    final out = <DateTime>{};
    var d = s;
    while (!d.isAfter(e)) { out.add(d); d = d.add(const Duration(days: 1)); }
    return out;
  }

  DateTime? _dateAtGlobal(Offset global) {
    for (final entry in _cellKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(global)) return DateTime.parse(entry.key);
    }
    return null;
  }

  @override
  void dispose() {
    _incomeCtrl.dispose(); _creditCtrl.dispose();
    _debitCtrl.dispose();  _otherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: const Icon(Icons.arrow_back, color: _ink),
        title: const Text('가계부',
            style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _deselect,
              child: const Text('취소', style: TextStyle(color: _accent)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          _buildMonthNav(),
          Container(height: 1, color: _line),
          _buildSummaryBar(),
          Container(height: 1, color: _line),
          _buildDowRow(),
          Container(height: 1, color: _line),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: _buildCalendar(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMonthNav() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.chevron_left_rounded, color: _ink, size: 26),
        Text('$_year. $_month',
            style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
        const Icon(Icons.chevron_right_rounded, color: _ink, size: 26),
      ],
    ),
  );

  Widget _buildSummaryBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(children: [
      Expanded(child: _summaryItem('수입', _totalIncome, _incomeColor)),
      Container(width: 1, height: 32, color: _line),
      Expanded(child: _summaryItem('지출', _totalExpense, _danger)),
      Container(width: 1, height: 32, color: _line),
      Expanded(child: _summaryItem('잔액', _totalIncome - _totalExpense, _ink)),
    ]),
  );

  Widget _summaryItem(String label, int amount, Color color) => Column(children: [
    Text(label, style: const TextStyle(color: _terti, fontSize: 11,
        fontWeight: FontWeight.w600, letterSpacing: 1.5)),
    const SizedBox(height: 4),
    Text('${_fmt.format(amount)}원',
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
        maxLines: 1, overflow: TextOverflow.ellipsis),
  ]);

  Widget _buildDowRow() {
    const labels = ['월','화','수','목','금','토','일'];
    return SizedBox(
      height: 28,
      child: Row(children: List.generate(7, (i) => Expanded(
        child: Center(child: Text(labels[i],
            style: TextStyle(
              color: i == 6 ? _danger : _terti,
              fontSize: 12, fontWeight: FontWeight.w600,
            ))),
      ))),
    );
  }

  Widget _buildCalendar() {
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
        child: Row(children: List.generate(7, (col) {
          final idx = row * 7 + col - _firstOffset;
          if (idx < 0 || idx >= _daysInMonth) return const Expanded(child: SizedBox());
          return Expanded(child: _buildCell(DateTime(_year, _month, idx + 1)));
        })),
      ));

      if (editorRow == row) rows.add(_buildInlineEditor());
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        final d = _dateAtGlobal(e.position);
        if (d == null) return;
        setState(() { _dragStart = d; _dragCurrent = d; _isDragging = false; });
      },
      onPointerMove: (e) {
        if (_dragStart == null) return;
        final d = _dateAtGlobal(e.position);
        if (d == null || d == _dragCurrent) return;
        _dragCurrent = d;
        setState(() {
          _isDragging = true;
          _selected..clear()..addAll(_rangeBetween(_dragStart!, d));
        });
      },
      onPointerUp: (e) {
        if (_dragStart != null && !_isDragging) {
          _toggleSingle(_dragStart!);
        } else if (_isDragging) {
          setState(() => _isDragging = false);
          _prefillForm();
        }
        _dragStart = null; _dragCurrent = null;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(children: rows),
      ),
    );
  }

  Widget _buildCell(DateTime date) {
    final key = _key(date);
    final gkey = _cellKeys[key] = GlobalKey();
    final isSun = date.weekday == DateTime.sunday;
    final isSelected = _selected.contains(date);
    final isToday = date.day == 19 && date.month == 6;
    final income = _incomeOf(key);
    final cr = _catOf(key, '신용카드');
    final db = _catOf(key, '체크+현금');
    final ot = _catOf(key, '기타');

    return Container(
      key: gkey,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _expenseBg(date),
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: _accent, width: 2)
            : isToday
                ? Border.all(color: _accent, width: 1.5)
                : Border.all(color: _line.withValues(alpha: 0.6), width: 0.8),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleSingle(date),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSun ? _danger : _ink,
                  )),
              const SizedBox(height: 1),
              Expanded(child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (income > 0) _amtLine(income, _incomeColor, prefix: '+'),
                    if (cr > 0) _amtLine(cr, _creditColor),
                    if (db > 0) _amtLine(db, _debitColor),
                    if (ot > 0) _amtLine(ot, _otherColor),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amtLine(int amount, Color color, {String prefix = ''}) {
    String s;
    if (amount >= 10000) s = '${(amount / 10000).round()}만';
    else s = _fmt.format(amount);
    return Text('$prefix$s',
        style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w700, height: 1.25));
  }

  Widget _buildInlineEditor() {
    final sorted = _selected.toList()..sort();
    final isRange = sorted.length > 1;
    const wd = ['월','화','수','목','금','토','일'];
    final title = isRange
        ? '${sorted.first.month}월 ${sorted.first.day}일 – ${sorted.last.month}월 ${sorted.last.day}일'
        : '${sorted.first.month}월 ${sorted.first.day}일 (${wd[sorted.first.weekday - 1]})';
    final caption = isRange
        ? '${sorted.length}일 동안 같은 금액으로 기록돼요'
        : '이 날의 수입과 지출을 적어요';
    final hasExisting = !isRange && _hasData(_key(sorted.first));

    return Container(
      margin: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _surf,
        border: Border.all(color: _lineS, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title,
                style: const TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.w600,
                    letterSpacing: -0.3),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: _deselect,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 4),
                child: Icon(Icons.close_rounded, size: 20, color: _sub),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(caption, style: const TextStyle(color: _terti, fontSize: 12.5)),
        const SizedBox(height: 20),
        _PreviewAmountField(label: '수익',     ctrl: _incomeCtrl, color: _incomeColor, fmt: _fmt),
        const SizedBox(height: 16),
        _PreviewAmountField(label: '신용카드', ctrl: _creditCtrl, color: _creditColor, fmt: _fmt),
        const SizedBox(height: 16),
        _PreviewAmountField(label: '체크/현금', ctrl: _debitCtrl, color: _debitColor, fmt: _fmt),
        const SizedBox(height: 16),
        _PreviewAmountField(label: '기타',     ctrl: _otherCtrl, color: _otherColor, fmt: _fmt),
        const SizedBox(height: 24),
        Row(children: [
          if (hasExisting) ...[
            GestureDetector(
              onTap: _deselect,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: _danger, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('삭제',
                    style: TextStyle(color: _danger, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: GestureDetector(
            onTap: _deselect,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(4)),
              child: Text(hasExisting ? '수정' : '저장',
                  style: const TextStyle(color: _bg, fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          )),
        ]),
      ]),
    );
  }
}

class _PreviewAmountField extends StatefulWidget {
  final String label;
  final TextEditingController ctrl;
  final Color color;
  final NumberFormat fmt;
  const _PreviewAmountField({required this.label, required this.ctrl,
      required this.color, required this.fmt});
  @override
  State<_PreviewAmountField> createState() => _PreviewAmountFieldState();
}

class _PreviewAmountFieldState extends State<_PreviewAmountField> {
  final _focus = FocusNode();

  @override
  void initState() { super.initState(); _focus.addListener(_rebuild); }
  void _rebuild() { if (mounted) setState(() {}); }
  @override
  void dispose() { _focus.removeListener(_rebuild); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final lineColor = focused ? widget.color : _line;
    return Container(
      padding: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor, width: focused ? 1.6 : 1)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(widget.label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: focused ? widget.color : _sub)),
        const SizedBox(width: 16),
        Expanded(child: TextField(
          controller: widget.ctrl,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          cursorColor: widget.color,
          style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none,
            hintText: '0',
            hintStyle: TextStyle(color: _terti, fontSize: 20, fontWeight: FontWeight.w300),
          ),
          onChanged: (v) {
            final n = v.replaceAll(RegExp(r'[^0-9]'), '');
            final f = n.isEmpty ? '' : widget.fmt.format(int.parse(n));
            if (f != widget.ctrl.text) {
              widget.ctrl.value = TextEditingValue(
                  text: f, selection: TextSelection.collapsed(offset: f.length));
            }
          },
        )),
        const SizedBox(width: 7),
        const Text('원', style: TextStyle(color: _sub, fontSize: 13)),
      ]),
    );
  }
}
