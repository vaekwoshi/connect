/// 연말정산 간소화 자료(PDF에서 추출한 텍스트) → 공제 가능액 파싱.
///
/// 2층 파서의 "2층(순수 Dart)" — 파일/PDF I/O 없이 텍스트만 받아 필드를 뽑는다.
/// 1층(PDF→텍스트)은 UI 배선 시 얇은 어댑터로 붙인다. 이 함수는 `flutter test`로
/// 실제 추출 텍스트(test/fixtures)를 골든으로 완전 검증된다.
///
/// 구조(2025 귀속 실파일 기준):
/// - 카테고리 1개 = 페이지 1개 이상, 머리글에 `[카테고리]` 표기
/// - 건강보험·국민연금 → `총합계 N`, 고용보험 → `합계 N`
/// - 보장성·의료비·실손 → `인별합계금액 N` (섹션 내 마지막)
/// - 카드(신용/직불/현금) → `일반 … 합계금액` 집계 헤더 다음 데이터행의 마지막 숫자
class GansoDeductions {
  final int creditCard; // 신용카드 사용액 합계
  final int debitCard; // 직불카드 등 합계
  final int cashReceipt; // 현금영수증 합계
  final int nationalPension; // 국민연금보험료
  final int healthInsurance; // 건강보험(노인장기요양 포함)
  final int employmentInsurance; // 고용보험
  final int lifeInsurance; // 보장성보험(장애인전용 포함)
  final int medical; // 의료비 총액
  final int medicalReimbursed; // 실손의료보험금(의료비에서 차감)
  final int medicalInfertility; // 난임시술비(30% 고율 — 의료비 총액에 포함)
  final int education; // 교육비
  final int donation; // 기부금
  final int pensionSavings; // 연금저축
  final int mortgage; // 장기주택저당차입금 이자
  final int rent; // 월세액

  const GansoDeductions({
    this.creditCard = 0,
    this.debitCard = 0,
    this.cashReceipt = 0,
    this.nationalPension = 0,
    this.healthInsurance = 0,
    this.employmentInsurance = 0,
    this.lifeInsurance = 0,
    this.medical = 0,
    this.medicalReimbursed = 0,
    this.medicalInfertility = 0,
    this.education = 0,
    this.donation = 0,
    this.pensionSavings = 0,
    this.mortgage = 0,
    this.rent = 0,
  });

  /// 체크+현금 (앱 `debitCard` 필드 = 직불 + 현금영수증)
  int get debitCash => debitCard + cashReceipt;

  /// 4대보험 소득공제 = 국민연금 + 건강 + 고용
  int get fourMajorInsurance => nationalPension + healthInsurance + employmentInsurance;

  /// 실손 차감 후 의료비
  int get medicalNet => (medical - medicalReimbursed) < 0 ? 0 : (medical - medicalReimbursed);

  @override
  String toString() => 'GansoDeductions(card:$creditCard, debit:$debitCard, cash:$cashReceipt, '
      '국민연금:$nationalPension, 건강:$healthInsurance, 고용:$employmentInsurance, '
      '보장성:$lifeInsurance, 의료비:$medical, 실손:$medicalReimbursed, '
      '교육:$education, 기부:$donation, 연금저축:$pensionSavings, 주담대:$mortgage, 월세:$rent)';
}

enum _Cat {
  health,
  employment,
  nationalPension,
  life,
  reimbursed,
  medical,
  credit,
  debit,
  cash,
  education,
  donation,
  pensionSavings,
  mortgage,
  rent,
}

/// 머리글 라인에서 카테고리 판별. 순서 주의: '실손'을 '의료비'보다 먼저.
_Cat? _detectCat(String line) {
  if (!line.contains('[')) return null;
  // 대괄호 내부만 추출(공백 제거)
  final m = RegExp(r'\[([^\]]*)\]').firstMatch(line);
  final inner = (m?.group(1) ?? '').replaceAll(' ', '');
  if (inner.isEmpty) return null;
  if (inner.contains('건강보험료')) return _Cat.health;
  if (inner.contains('고용보험료')) return _Cat.employment;
  if (inner.contains('국민연금')) return _Cat.nationalPension;
  if (inner.contains('실손')) return _Cat.reimbursed;
  if (inner.contains('보장성')) return _Cat.life;
  if (inner.contains('의료비')) return _Cat.medical;
  if (inner.contains('신용카드')) return _Cat.credit;
  if (inner.contains('직불카드')) return _Cat.debit;
  if (inner.contains('현금영수증')) return _Cat.cash;
  if (inner.contains('교육비')) return _Cat.education;
  if (inner.contains('기부금')) return _Cat.donation;
  if (inner.contains('연금저축')) return _Cat.pensionSavings;
  if (inner.contains('장기주택') || inner.contains('주택자금')) return _Cat.mortgage;
  if (inner.contains('월세')) return _Cat.rent;
  return null;
}

/// 라인에서 마지막 금액 토큰(콤마 천단위) → int. 없으면 null.
int? _lastNum(String line) {
  final ms = RegExp(r'\d{1,3}(?:,\d{3})+|\d+').allMatches(line).toList();
  if (ms.isEmpty) return null;
  return int.tryParse(ms.last.group(0)!.replaceAll(',', ''));
}

/// `라벨 N` 형태에서 라벨이 든 라인의 마지막 숫자(섹션 내 마지막 등장).
/// 공백 무관 매칭 — Syncfusion layout은 '납입금액계3,000,000'처럼 공백이 없음.
int? _byLabelLast(List<String> slice, String label) {
  final key = label.replaceAll(' ', '');
  int? found;
  for (final ln in slice) {
    if (ln.replaceAll(' ', '').contains(key)) {
      final n = _lastNum(ln);
      if (n != null) found = n;
    }
  }
  return found;
}

/// 의료비 세부 — keyword + '인별합계금액'이 같은 라인에 든 경우의 금액.
/// (노트 라인은 '인별합계금액'을 포함하지 않아 오매칭 안 됨)
int? _medicalSub(List<String> slice, String keyword) {
  int? found;
  for (final ln in slice) {
    final s = ln.replaceAll(' ', '');
    if (s.contains(keyword) && s.contains('인별합계금액')) {
      final n = _lastNum(ln);
      if (n != null) found = n;
    }
  }
  return found;
}

/// 카드 집계: `일반 … 합계금액` 헤더 다음 데이터행의 **최댓값**(=합계금액).
/// Syncfusion layout은 열이 붙어 추출됨("2,724,03100002,724,031") → 마지막숫자가
/// 깨지므로 최댓값을 취한다(합계금액 ≥ 각 열, 콤마 경계로 토큰 안 섞임).
int? _cardRowMax(List<String> slice) {
  for (var i = 0; i < slice.length; i++) {
    final ln = slice[i];
    if (ln.contains('합계금액') && ln.contains('일반')) {
      for (var j = i + 1; j < slice.length && j < i + 4; j++) {
        final ns = RegExp(r'\d{1,3}(?:,\d{3})+|\d+')
            .allMatches(slice[j])
            .map((m) => int.parse(m.group(0)!.replaceAll(',', '')))
            .toList();
        if (ns.isNotEmpty) return ns.reduce((a, b) => a > b ? a : b);
      }
    }
  }
  return null;
}

GansoDeductions parseSimplifiedText(String text) {
  final lines = text.split(RegExp(r'\r?\n'));

  // 섹션 경계 수집
  final marks = <({int idx, _Cat cat})>[];
  for (var i = 0; i < lines.length; i++) {
    final c = _detectCat(lines[i]);
    if (c != null) marks.add((idx: i, cat: c));
  }

  final acc = <_Cat, int>{};
  int infertility = 0; // 난임시술비(의료비 내 30% 고율 — 별도 누적)
  void put(_Cat c, int? v) {
    if (v == null) return;
    final cur = acc[c] ?? 0;
    if (v > cur) acc[c] = v; // 멀티페이지 카테고리는 최대(=인별 총계) 채택
  }

  for (var m = 0; m < marks.length; m++) {
    final start = marks[m].idx;
    final end = (m + 1 < marks.length) ? marks[m + 1].idx : lines.length;
    final slice = lines.sublist(start, end);
    final cat = marks[m].cat;
    switch (cat) {
      case _Cat.health:
      case _Cat.nationalPension:
        put(cat, _byLabelLast(slice, '총합계'));
        break;
      case _Cat.employment:
        put(cat, _byLabelLast(slice, '총합계') ?? _byLabelLast(slice, '합계'));
        break;
      case _Cat.life:
      case _Cat.reimbursed:
        put(cat, _byLabelLast(slice, '인별합계금액'));
        break;
      case _Cat.medical:
        put(cat, _byLabelLast(slice, '인별합계금액'));
        // 난임시술비 — '난임' + '인별합계금액' 둘 다 든 라인만(노트 오매칭 방지)
        final inf = _medicalSub(slice, '난임');
        if (inf != null && inf > infertility) infertility = inf;
        break;
      case _Cat.credit:
      case _Cat.debit:
      case _Cat.cash:
        // 신용/직불은 '인별합계금액'이 깔끔, 현금은 없어 집계행 최댓값으로.
        put(cat, _byLabelLast(slice, '인별합계금액') ?? _cardRowMax(slice));
        break;
      case _Cat.education:
      case _Cat.donation:
      case _Cat.pensionSavings:
      case _Cat.mortgage:
      case _Cat.rent:
        // 실파일 샘플 미확보 — 일반 패턴(인별합계금액/납입금액 계/합계)로 best-effort
        put(cat, _byLabelLast(slice, '인별합계금액') ??
            _byLabelLast(slice, '납입금액 계') ??
            _byLabelLast(slice, '합계'));
        break;
    }
  }

  return GansoDeductions(
    creditCard: acc[_Cat.credit] ?? 0,
    debitCard: acc[_Cat.debit] ?? 0,
    cashReceipt: acc[_Cat.cash] ?? 0,
    nationalPension: acc[_Cat.nationalPension] ?? 0,
    healthInsurance: acc[_Cat.health] ?? 0,
    employmentInsurance: acc[_Cat.employment] ?? 0,
    lifeInsurance: acc[_Cat.life] ?? 0,
    medical: acc[_Cat.medical] ?? 0,
    medicalReimbursed: acc[_Cat.reimbursed] ?? 0,
    medicalInfertility: infertility,
    education: acc[_Cat.education] ?? 0,
    donation: acc[_Cat.donation] ?? 0,
    pensionSavings: acc[_Cat.pensionSavings] ?? 0,
    mortgage: acc[_Cat.mortgage] ?? 0,
    rent: acc[_Cat.rent] ?? 0,
  );
}
