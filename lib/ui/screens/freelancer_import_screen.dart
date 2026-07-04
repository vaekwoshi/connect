import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../components/occupation_search_bottom_sheet.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/occupation_data.dart';
import '../../core/parsing/pdf_text_extractor.dart';
import '../../core/parsing/freelancer_income_parser.dart';
import '../../core/tax_engine/freelancer_tax.dart';

/// 프리랜서 ① — 사업소득 원천징수영수증/지급명세서 PDF를 온디바이스로 파싱해
/// 5월 종합소득세 가상 신고서를 만든다. 모두 기기 안에서 처리.
class FreelancerImportScreen extends StatefulWidget {
  final String userType;
  const FreelancerImportScreen({super.key, required this.userType});

  @override
  State<FreelancerImportScreen> createState() => _FreelancerImportScreenState();
}

class _FreelancerImportScreenState extends State<FreelancerImportScreen> {
  final _fmt = NumberFormat('#,###');
  FreelancerReceipt? _r;
  bool _busy = false;
  bool _manualMode = true; // 기본 직접 입력 (PDF 없이 총수입+업종으로 계산)
  OccupationInfo? _occupation; // 직접 입력 모드 업종(경비율) 선택
  String? _error;

  final Map<String, TextEditingController> _ctrls = {};

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String k) => _ctrls.putIfAbsent(k, () => TextEditingController());
  int _v(String k) => int.tryParse((_ctrls[k]?.text ?? '').replaceAll(',', '')) ?? 0;
  void _seed(String k, int v) => _ctrl(k).text = v == 0 ? '' : _fmt.format(v);

  /// PDF 모드는 추출·보정값을, 직접 입력 모드는 총수입+업종으로 계산한 값을 쓴다.
  FreelancerReceipt _eff() => _manualMode
      ? _manualReceipt()
      : FreelancerReceipt(
          grossIncome: _v('gross'),
          incomeAmount: _v('income'),
          decidedTax: _v('decided'),
          finalSettlement: _v('final'),
        );

  /// 직접 입력 모드: 연간 총수입 + 업종(경비율)로 종소세 엔진을 돌려
  /// 소득금액·결정세액·차감납부를 도출한다. (진단과 동일 엔진 재사용)
  FreelancerReceipt _manualReceipt() {
    final gross = _v('gross');
    if (gross <= 0 || _occupation == null) return const FreelancerReceipt();
    final r = FreelancerTaxCalculator.calculateTaxSimulation(
      accumulatedIncome: gross.toDouble(),
      inputMonths: 12, // 기록은 연간 신고서 기준
      allowanceCount: 0,
      occupationCode: _occupation!.code,
      yellowUmbrellaPayment: _v('yellow').toDouble(),
    );
    // finalSettlement은 음수=환급. expectedRefundOrPayment(+환급)의 부호 반전.
    return FreelancerReceipt(
      grossIncome: gross,
      incomeAmount: r.estimatedBusinessIncome.round(),
      decidedTax: r.annualTotalTax.round(),
      finalSettlement: (r.annualTotalTax - r.annualEstimatedTotalWithholding).round(),
    );
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res == null) {
        setState(() => _busy = false);
        return;
      }
      final bytes = res.files.single.bytes;
      if (bytes == null) {
        setState(() {
          _busy = false;
          _error = '파일을 읽지 못했어요. 다시 선택해 주세요.';
        });
        return;
      }
      final r = parseFreelancerText(extractPdfText(bytes));
      setState(() {
        _r = r;
        _seed('gross', r.grossIncome);
        _seed('income', r.incomeAmount);
        _seed('decided', r.decidedTax);
        _seed('final', r.finalSettlement);
        _busy = false;
      });
    } catch (e) {
      debugPrint('프리랜서 PDF 파싱 실패: $e');
      setState(() {
        _busy = false;
        _error = 'PDF를 분석하지 못했어요. 사업소득 원천징수영수증 PDF가 맞는지 확인해 주세요.';
      });
    }
  }

  Future<void> _save() async {
    final r = _eff();
    // 진단 자동기입용 원시값 영속화 (직장인과 동일 계약).
    // grossSalary 키는 진단에서 프리랜서 총수입 입력칸으로 들어간다.
    await dbService.saveAnnualRecord(widget.userType, {
      'grossSalary': r.grossIncome,
      'decidedTax': r.decidedTax,
      if (_manualMode && _occupation != null) 'occupationCode': _occupation!.code,
    });
    await dbService.saveReportDraft(
      widget.userType,
      reportType: '종합소득세',
      items: buildFreelancerReportItems(r),
      finalAmount: r.finalSettlement.toDouble(),
      isRefund: r.isRefund,
    );
    if (mounted) Navigator.pop(context, true);
  }

  String _won(int v) => '${_fmt.format(v)}원';

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final r = _r;
    // 직접 입력: 총수입+업종이 채워지면 결과 노출. PDF: 파싱 완료 시.
    final manualReady = _v('gross') > 0 && _occupation != null;
    final showResult = _manualMode ? manualReady : (r != null);

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
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            Text('소득·경비 기록'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 12),
            Text(_manualMode ? '수입과 업종을\n직접 적어주세요' : '사업소득 자료를\n가져오세요',
                style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
            const SizedBox(height: 10),
            Text(_manualMode
                ? '연간 총수입과 업종을 고르면 경비율로 소득금액·세금을 계산해요. 모두 기기 안에서만 분석돼요.'
                : '사업소득 원천징수영수증·지급명세서 PDF로 5월 종합소득세 신고서를 만들어요. 기기 안에서만 분석돼요.',
                style: AppTheme.sans(14, sub, height: 1.55)),
            const SizedBox(height: 20),

            _modeToggle(),
            const SizedBox(height: 8),

            // ── A) PDF 가져오기 모드 ──
            if (!_manualMode) ...[
              AppTheme.hairline(context),
              _slot(r),
              AppTheme.hairline(context),
              if (_busy) ...[
                const SizedBox(height: 20),
                Center(child: Text('PDF 분석 중…', style: AppTheme.sans(13, sub))),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: AppTheme.sans(13, AppTheme.colorDanger, height: 1.45)),
              ],
              if (r != null) ...[
                const SizedBox(height: 28),
                _confirmSection(),
              ],
            ]
            // ── B) 직접 입력 모드 ──
            else ...[
              const SizedBox(height: 12),
              _manualSection(),
            ],

            // ── 종소세 결과 + 저장 (양쪽 공통) ──
            if (showResult) ...[
              const SizedBox(height: 24),
              _resultBlock(),
              const SizedBox(height: 28),
              _saveButton(),
            ],
          ],
        ),
      ),
    );
  }

  /// PDF / 직접입력 모드 토글 (직장인 기록 화면과 동일 패턴).
  Widget _modeToggle() {
    return Row(children: [
      _modeChip('직접 입력', true),
      const SizedBox(width: 8),
      _modeChip('PDF로 가져오기', false),
    ]);
  }

  Widget _modeChip(String label, bool manual) {
    final selected = _manualMode == manual;
    final accent = AppTheme.accentColor(context);
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return GestureDetector(
      onTap: () => setState(() {
        if (_manualMode == manual) return;
        _manualMode = manual;
        _error = null;
        // 모드 전환 시 이전 입력·파싱 결과 비우기.
        _r = null;
        _occupation = null;
        for (final c in _ctrls.values) {
          c.clear();
        }
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? accent : AppTheme.line(context),
            width: selected ? 1.4 : 1.0,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppTheme.sans(13, selected ? ink : sub,
                weight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  /// 직접 입력 패널 — 연간 총수입 + 업종(경비율) + 선택 노란우산.
  Widget _manualSection() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('핵심 항목'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        Text('PDF 없이 연간 총수입과 업종만 고르면 경비율로 소득금액·세금을 계산해드려요.',
            style: AppTheme.sans(13, sub, height: 1.45)),
        const SizedBox(height: 16),
        // 업종 선택
        Text('업종코드 (경비율 기준)', style: AppTheme.sans(14, sub, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final result = await OccupationSearchBottomSheet.show(context);
            if (result != null) setState(() => _occupation = result);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              border: Border.all(color: AppTheme.line(context)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  _occupation == null ? '업종을 검색해 주세요' : '${_occupation!.name} (${_occupation!.code})',
                  style: AppTheme.sans(14, _occupation == null ? AppTheme.inkTertiary(context) : ink,
                      weight: _occupation == null ? FontWeight.w400 : FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.search_rounded, size: 18, color: AppTheme.inkSecondary(context)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        _editRow('연간 총수입금액 (3.3% 떼기 전)', 'gross'),
        _editRow('노란우산공제 납입액 (선택)', 'yellow'),
      ],
    );
  }

  Widget _slot(FreelancerReceipt? r) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final done = r != null;
    return GestureDetector(
      onTap: _busy ? null : _pick,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(done ? Icons.check_circle_outline_rounded : Icons.upload_file_outlined,
              size: 22, color: done ? accent : sub),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('사업소득 원천징수영수증', style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 3),
              Text(done ? '총수입 ${_won(r.grossIncome)} · ${r.isRefund ? '환급' : '추가납부'} ${_won(r.settlementAbs)}' : '총수입·원천징수(3.3%) 자료',
                  style: AppTheme.sans(12, done ? accent : sub, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(done ? '다시' : 'PDF 선택', style: AppTheme.sans(12, tert, weight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _confirmSection() {
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('추출값 확인·보정'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 8),
        Text('PDF에서 읽은 값이에요. 다르면 고쳐주세요.', style: AppTheme.sans(13, sub, height: 1.45)),
        const SizedBox(height: 14),
        _editRow('총수입금액', 'gross'),
        _editRow('소득금액 (수입−경비)', 'income'),
        _editRow('결정세액', 'decided'),
        _editRow('차감납부세액 (−환급)', 'final', allowNeg: true),
      ],
    );
  }

  Widget _editRow(String label, String key, {bool allowNeg = false}) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context)))),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: AppTheme.sans(14, AppTheme.ink(context)))),
        _numField(key, allowNeg: allowNeg),
        const SizedBox(width: 8),
        Text('원', style: AppTheme.sans(15, AppTheme.inkSecondary(context), weight: FontWeight.w600)),
      ]),
    );
  }

  Widget _numField(String key, {bool allowNeg = false}) {
    final ink = AppTheme.ink(context);
    return SizedBox(
      width: 150,
      height: 38,
      child: TextField(
        controller: _ctrl(key),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        textAlign: TextAlign.right,
        style: AppTheme.sans(14, ink, weight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          hintText: '0',
          hintStyle: AppTheme.sans(14, AppTheme.inkTertiary(context)),
          filled: true,
          fillColor: AppTheme.surface(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.accentColor(context), width: 1.5)),
        ),
        onChanged: (val) {
          final neg = allowNeg && val.trimLeft().startsWith('-');
          final n = val.replaceAll(RegExp(r'[^0-9]'), '');
          final f = n.isEmpty ? (neg ? '-' : '') : '${neg ? '-' : ''}${_fmt.format(int.parse(n))}';
          _ctrl(key).value = TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
          setState(() {});
        },
      ),
    );
  }

  Widget _resultBlock() {
    final r = _eff();
    final sub = AppTheme.inkSecondary(context);
    final accent = r.isRefund ? AppTheme.accentColor(context) : AppTheme.colorDanger;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.lineStrong(context), width: 1.4), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('5월 종합소득세', style: AppTheme.label(context)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: accent, width: 1), borderRadius: BorderRadius.circular(2)),
            child: Text(r.isRefund ? '환급' : '추가납부', style: AppTheme.sans(11, accent, weight: FontWeight.w700, spacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(_fmt.format(r.settlementAbs), style: AppTheme.serif(34, accent, spacing: -1.2, height: 1.0)),
          const SizedBox(width: 5),
          Text('원', style: AppTheme.sans(15, sub, weight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text('기납부 3.3%(${_won(r.withheldTax)}) − 결정세액(${_won(r.decidedTax)}) 기준이에요.',
            style: AppTheme.sans(12, sub, height: 1.45)),
      ]),
    );
  }

  Widget _saveButton() {
    final bg = AppTheme.backgroundColor(context);
    return GestureDetector(
      onTap: _save,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppTheme.ink(context), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('종합소득세 신고서로 저장', style: AppTheme.sans(15, bg, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16, color: bg),
        ]),
      ),
    );
  }
}
