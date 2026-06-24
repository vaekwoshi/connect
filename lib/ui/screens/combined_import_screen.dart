import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';

import '../theme/app_theme.dart';
import '../components/occupation_search_bottom_sheet.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/occupation_data.dart';
import '../../core/parsing/pdf_text_extractor.dart';
import '../../core/parsing/withholding_parser.dart';
import '../../core/parsing/freelancer_income_parser.dart';
import '../../core/parsing/combined_report.dart';
import '../../core/tax_engine/freelancer_tax.dart';

/// N잡러 ① — 근로 원천징수영수증 + 사업소득 지급명세서 PDF를 온디바이스로 파싱해
/// 합산 종합소득세 가상 신고서를 만든다.
class CombinedImportScreen extends StatefulWidget {
  final String userType;
  const CombinedImportScreen({super.key, required this.userType});

  @override
  State<CombinedImportScreen> createState() => _CombinedImportScreenState();
}

class _CombinedImportScreenState extends State<CombinedImportScreen> {
  final _fmt = NumberFormat('#,###');
  WithholdingReceipt? _labor;
  FreelancerReceipt? _biz;
  bool _busy = false;
  bool _manualMode = true; // 기본 직접 입력 (PDF 없이도 합산 기록 가능)
  OccupationInfo? _occupation; // 직접 입력 모드 사업 업종(경비율)
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

  WithholdingReceipt _effLabor() => WithholdingReceipt(grossSalary: _v('salary'), decidedTax: _v('decided'));

  /// 사업소득. PDF 모드는 파싱된 소득금액(net)을, 직접 입력 모드는 총수입+업종을
  /// 경비율 엔진(진단과 동일)에 돌려 소득금액(net)을 도출한다. buildCombinedReport는
  /// occupationCode=''로 이 net 소득금액을 그대로 받는다.
  FreelancerReceipt _effBiz() {
    if (_manualMode) {
      final gross = _v('bizGross');
      if (gross <= 0 || _occupation == null) return const FreelancerReceipt();
      final r = FreelancerTaxCalculator.calculateTaxSimulation(
        accumulatedIncome: gross.toDouble(),
        inputMonths: 12,
        allowanceCount: 0,
        occupationCode: _occupation!.code,
      );
      return FreelancerReceipt(grossIncome: gross, incomeAmount: r.estimatedBusinessIncome.round());
    }
    return FreelancerReceipt(incomeAmount: _v('bizIncome'), grossIncome: _biz?.grossIncome ?? 0);
  }

  Future<void> _pick({required bool isLabor}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
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
      final text = extractPdfText(bytes);
      setState(() {
        if (isLabor) {
          final w = parseWithholdingText(text);
          _labor = w;
          _seed('salary', w.grossSalary);
          _seed('decided', w.decidedTax);
        } else {
          final b = parseFreelancerText(text);
          _biz = b;
          _seed('bizIncome', b.incomeAmount);
        }
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'PDF를 분석하지 못했어요. 홈택스에서 받은 PDF가 맞는지 확인해 주세요.';
      });
    }
  }

  Future<void> _save() async {
    final r = buildCombinedReport(_effLabor(), _effBiz());
    // 진단 자동기입용 원시값 영속화. 진단과 동일한 '총수입+업종' 모델로 통일했으므로
    // 근로 총급여·사업 총수입·업종코드를 그대로 넘겨 진단이 완전 자동기입된다.
    final bizGrossVal = _manualMode ? _v('bizGross') : (_biz?.grossIncome ?? 0);
    await dbService.saveAnnualRecord(widget.userType, {
      'grossSalary': _v('salary'),
      'decidedTax': _v('decided'),
      'bizGrossIncome': bizGrossVal,
      if (_manualMode && _occupation != null) 'occupationCode': _occupation!.code,
    });
    await dbService.saveReportDraft(widget.userType,
        reportType: '종합소득세', items: r.items, finalAmount: r.finalAmount, isRefund: r.isRefund);
    if (mounted) Navigator.pop(context, true);
  }

  String _won(int v) => '${_fmt.format(v)}원';

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final both = _labor != null && _biz != null;
    // 수기 모드: 근로 입력 또는 (사업 총수입+업종)이 채워지면 합산 결과 노출.
    final hasManualInput = _v('salary') > 0 || (_v('bizGross') > 0 && _occupation != null);
    final showResult = _manualMode ? hasManualInput : both;

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
            Text('소득 기록'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 12),
            Text(_manualMode ? '근로·사업 소득을\n직접 적어주세요' : '근로 + 사업소득을\n합산해요',
                style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
            const SizedBox(height: 10),
            Text(_manualMode
                ? '근로 총급여와 사업 총수입·업종을 적으면 경비율로 소득금액을 잡아 합산 종합소득세를 계산해요. 모두 기기 안에서만 분석돼요.'
                : '근로 원천징수영수증과 사업소득 지급명세서로 5월 합산 종합소득세를 계산해요. 기기 안에서만 분석돼요.',
                style: AppTheme.sans(13.5, sub, height: 1.55)),
            const SizedBox(height: 20),

            _modeToggle(),
            const SizedBox(height: 8),

            // ── A) PDF 가져오기 모드 ──
            if (!_manualMode) ...[
              AppTheme.hairline(context),
              _slot(label: '근로 원천징수영수증', hint: '총급여·근로 기납부', done: _labor != null,
                  summary: _labor == null ? null : '총급여 ${_won(_labor!.grossSalary)}', onTap: _busy ? null : () => _pick(isLabor: true)),
              AppTheme.hairline(context),
              _slot(label: '사업소득 지급명세서', hint: '사업 수입·소득금액', done: _biz != null,
                  summary: _biz == null ? null : '소득금액 ${_won(_biz!.incomeAmount)}', onTap: _busy ? null : () => _pick(isLabor: false)),
              AppTheme.hairline(context),
              if (_busy) ...[
                const SizedBox(height: 20),
                Center(child: Text('PDF 분석 중…', style: AppTheme.sans(13, sub))),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: AppTheme.sans(13, AppTheme.colorDanger, height: 1.45)),
              ],
              if (both) ...[
                const SizedBox(height: 28),
                _confirmSection(),
              ] else if (_labor != null || _biz != null) ...[
                const SizedBox(height: 24),
                Text('두 자료를 모두 넣으면 합산 결과를 보여드려요.', style: AppTheme.sans(13, sub, height: 1.45)),
              ],
            ]
            // ── B) 직접 입력 모드 ──
            else ...[
              const SizedBox(height: 12),
              _manualSection(),
            ],

            // ── 합산 결과 + 저장 (양쪽 공통) ──
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
        // 모드 전환 시 이전 입력·파싱 결과를 비워 혼선 방지.
        _labor = null;
        _biz = null;
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

  /// 직접 입력 패널 — 근로/사업 2단. 사업은 진단과 동일한 '총수입+업종' 모델로
  /// 받아 경비율 엔진이 소득금액을 잡는다(_effBiz). 기록·진단·신고서 입력 모델 통일.
  Widget _manualSection() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('근로소득'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 6),
        AppTheme.hairline(context),
        _editRow('총급여', 'salary'),
        _editRow('결정세액 (근로 기납부)', 'decided'),
        const SizedBox(height: 22),
        Text('사업소득'.toUpperCase(), style: AppTheme.label(context)),
        const SizedBox(height: 6),
        Text('업종을 고르면 경비율로 소득금액을 자동 계산해요.', style: AppTheme.sans(12.5, sub, height: 1.45)),
        const SizedBox(height: 10),
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
        const SizedBox(height: 14),
        _editRow('사업 총수입 (경비 빼기 전)', 'bizGross'),
      ],
    );
  }

  Widget _slot({required String label, required String hint, required bool done, String? summary, VoidCallback? onTap}) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(done ? Icons.check_circle_outline_rounded : Icons.upload_file_outlined, size: 22, color: done ? accent : sub),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppTheme.sans(15.5, ink, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 3),
              Text(summary ?? hint, style: AppTheme.sans(12.5, done ? accent : sub, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(done ? '다시' : 'PDF 선택', style: AppTheme.sans(12.5, tert, weight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _confirmSection() {
    final sub = AppTheme.inkSecondary(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('추출값 확인·보정'.toUpperCase(), style: AppTheme.label(context)),
      const SizedBox(height: 8),
      Text('PDF에서 읽은 값이에요. 다르면 고쳐주세요.', style: AppTheme.sans(13, sub, height: 1.45)),
      const SizedBox(height: 14),
      _editRow('근로 총급여', 'salary'),
      _editRow('근로 기납부(결정세액)', 'decided'),
      _editRow('사업 소득금액', 'bizIncome'),
    ]);
  }

  Widget _editRow(String label, String key) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.line(context)))),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: AppTheme.sans(13.5, AppTheme.ink(context)))),
        _numField(key),
      ]),
    );
  }

  Widget _numField(String key) {
    return AmountField(controller: _ctrl(key), width: 150, onChanged: (_) => setState(() {}));
  }

  Widget _resultBlock() {
    final r = buildCombinedReport(_effLabor(), _effBiz());
    final sub = AppTheme.inkSecondary(context);
    final accent = r.isRefund ? AppTheme.accentColor(context) : AppTheme.colorDanger;
    final abs = r.finalAmount.abs().round();
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppTheme.lineStrong(context), width: 1.4), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('5월 합산 종합소득세', style: AppTheme.label(context)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: accent, width: 1), borderRadius: BorderRadius.circular(2)),
            child: Text(r.isRefund ? '환급' : '추가납부', style: AppTheme.sans(11, accent, weight: FontWeight.w700, spacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(_fmt.format(abs), style: AppTheme.serif(34, accent, spacing: -1.2, height: 1.0)),
          const SizedBox(width: 5),
          Text('원', style: AppTheme.sans(15, sub, weight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text('근로 + 사업을 합산하면 세율 구간이 올라갈 수 있어요. 추정치예요.', style: AppTheme.sans(12.5, sub, height: 1.45)),
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
          Text('합산 신고서로 저장', style: AppTheme.sans(15.5, bg, weight: FontWeight.w700)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 16, color: bg),
        ]),
      ),
    );
  }
}
