/// 사업소득 원천징수영수증·지급명세서([별지23], PDF 추출 텍스트) → 프리랜서 종소세 값.
///
/// ⚠️ 실제 홈택스 PDF 샘플 미확보 — 앵커 문자열은 [별지23(3)] 서식 구조 기반 추정.
/// 구조·로직은 합성 픽스처로 검증. 실파일 확보 시 앵커만 보정하면 됨.
///
/// 핵심: 총수입금액(합계124) · 소득금액 · 결정세액 · 차감납부세액(음수=환급).
/// 기납부(3.3% 원천징수)는 결정세액 − 차감납부로 도출.
class FreelancerReceipt {
  final int grossIncome; // 총수입금액
  final int incomeAmount; // 소득금액(수입 − 경비)
  final int decidedTax; // 결정세액
  final int finalSettlement; // 차감 납부할 세액(음수=환급)

  const FreelancerReceipt({
    this.grossIncome = 0,
    this.incomeAmount = 0,
    this.decidedTax = 0,
    this.finalSettlement = 0,
  });

  /// 기납부세액(3.3% 원천징수) = 결정세액 − 차감납부.
  int get withheldTax => decidedTax - finalSettlement;
  bool get isRefund => finalSettlement < 0;
  int get settlementAbs => finalSettlement.abs();

  @override
  String toString() =>
      'FreelancerReceipt(수입:$grossIncome, 소득금액:$incomeAmount, 결정:$decidedTax, '
      '기납부:$withheldTax, 차감:$finalSettlement)';
}

final _numRe = RegExp(r'-?\d{1,3}(?:,\d{3})+|-?\d+');
List<int> _nums(String line) =>
    _numRe.allMatches(line).map((m) => int.parse(m.group(0)!.replaceAll(',', ''))).toList();

String _sp(String s) => s.replaceAll(' ', '');
bool _has(String line, String label) => _sp(line).contains(_sp(label));

int _absMax(List<int> n) {
  var best = n.first;
  for (final v in n) {
    if (v.abs() > best.abs()) best = v;
  }
  return best;
}

/// 라벨 라인에서 절댓값이 가장 큰 숫자(부호 보존) — 필드번호·괄호식 잡숫자 회피.
/// 레이아웃 둔감: 라벨 라인에 숫자가 없으면(칸 분리 추출) 다음 [lookahead]줄까지 탐색.
/// 실제 홈택스 PDF는 라벨+값이 같은 줄(행 단위)이라 첫 경로로 해결됨 — 폴백은 칸이
/// 어긋나게 추출되는 변형 PDF 대비 보험.
int? _absMaxNumWith(List<String> lines, String label, {int lookahead = 2}) {
  // 1패스: 라벨과 숫자가 같은 줄(실제 홈택스 행 단위 추출) — 검증된 경로.
  for (final ln in lines) {
    if (!_has(ln, label)) continue;
    final n = _nums(ln);
    if (n.isNotEmpty) return _absMax(n);
  }
  // 2패스: 어느 라벨 줄에도 같은 줄 숫자가 없을 때만 다음 줄 탐색(칸 분리 추출 폴백).
  for (var i = 0; i < lines.length; i++) {
    if (!_has(lines[i], label)) continue;
    for (var j = i + 1; j <= i + lookahead && j < lines.length; j++) {
      final n = _nums(lines[j]);
      if (n.isNotEmpty) return _absMax(n);
    }
  }
  return null;
}

FreelancerReceipt parseFreelancerText(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  return FreelancerReceipt(
    grossIncome: _absMaxNumWith(lines, '합계(124)') ?? _absMaxNumWith(lines, '지급액') ?? 0,
    incomeAmount: _absMaxNumWith(lines, '소득금액') ?? 0,
    decidedTax: _absMaxNumWith(lines, '결정세액') ?? 0,
    finalSettlement: _absMaxNumWith(lines, '차감납부할세액') ?? _absMaxNumWith(lines, '차감납부') ?? 0,
  );
}

/// 프리랜서 종합소득세 가상 신고서 items.
List<Map<String, dynamic>> buildFreelancerReportItems(FreelancerReceipt r) => [
      {'title': '총수입금액', 'amount': r.grossIncome.toDouble(), 'isHeader': true},
      {'title': '(=) 소득금액 (수입 − 경비)', 'amount': r.incomeAmount.toDouble(), 'isHeader': true, 'highlight': true},
      {'title': '(=) 결정세액', 'amount': r.decidedTax.toDouble(), 'isHeader': true, 'highlight': true},
      {'title': '(-) 기납부세액 (3.3%)', 'amount': r.withheldTax.toDouble()},
    ];
