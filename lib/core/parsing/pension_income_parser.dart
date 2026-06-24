/// 연금소득 원천징수영수증([별지24호서식(5)], PDF 추출 텍스트) → 연금소득 합산용 값.
///
/// 구조([별지24(5)] 서식 기준):
/// - ⑭/⑮ 총연금액: 종합과세 합산 입력값(연금소득공제 전). 앱의 pensionIncome로 들어감.
/// - ⑯ 연금소득공제 · ⑰ 연금소득금액(=⑮-⑯)
/// - 결정세액 · 기납부세액 · 차감징수세액(음수=환급)
class PensionReceipt {
  final int grossPension; // 총연금액(⑭) — 합산 입력(공제 전)
  final int pensionIncomeAmount; // 연금소득금액(⑰)
  final int decidedTax; // 결정세액
  final int paidTax; // 기납부세액
  final int finalSettlement; // 차감징수세액(음수=환급)

  const PensionReceipt({
    this.grossPension = 0,
    this.pensionIncomeAmount = 0,
    this.decidedTax = 0,
    this.paidTax = 0,
    this.finalSettlement = 0,
  });

  bool get isRefund => finalSettlement < 0;
  int get settlementAbs => finalSettlement.abs();

  @override
  String toString() =>
      'PensionReceipt(총연금액:$grossPension, 연금소득금액:$pensionIncomeAmount, '
      '결정:$decidedTax, 기납부:$paidTax, 차감징수:$finalSettlement)';
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
/// (서식 번호 ⑪⑫⑬ 등은 원문자라 숫자 매칭에 안 걸림)
/// 레이아웃 둔감: 라벨 라인에 숫자가 없으면 다음 [lookahead]줄까지 탐색(칸 분리 추출 대비).
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

PensionReceipt parsePensionText(String text) {
  final lines = text.split(RegExp(r'\r?\n'));
  return PensionReceipt(
    // '총연금수령액'(⑪)은 '총연금액' 부분일치가 아니므로 ⑭/⑮만 잡힘.
    grossPension: _absMaxNumWith(lines, '총연금액') ?? 0,
    pensionIncomeAmount: _absMaxNumWith(lines, '연금소득금액') ?? 0,
    decidedTax: _absMaxNumWith(lines, '결정세액') ?? 0,
    paidTax: _absMaxNumWith(lines, '기납부세액') ?? 0,
    finalSettlement: _absMaxNumWith(lines, '차감징수') ?? 0,
  );
}
