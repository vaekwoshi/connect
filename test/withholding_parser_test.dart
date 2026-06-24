import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/parsing/simplified_data_parser.dart';
import 'package:secul/core/parsing/withholding_parser.dart';

void main() {
  group('원천징수영수증 파서 — 실제 추출 텍스트(골든)', () {
    late WithholdingReceipt w;

    setUpAll(() {
      final text = File('test/fixtures/wonchun_sample.txt').readAsStringSync();
      w = parseWithholdingText(text);
    });

    test('총급여·세액 추출', () {
      expect(w.grossSalary, 33295138);
      expect(w.paidTax, 806640, reason: '75 주(현)근무지 기납부세액');
      expect(w.decidedTax, 509066, reason: '73 결정세액');
      expect(w.finalSettlement, -297570, reason: '77 차감징수(음수=환급)');
      expect(w.isRefund, true);
      expect(w.settlementAbs, 297570);
    });

    test('이미 신고된 공제대상금액', () {
      expect(w.claimedMedical, 0);
      expect(w.claimedEducation, 0);
      expect(w.claimedRent, 0);
      expect(w.claimedLifeInsurance, 1000000, reason: '61 보장성 공제대상');
      expect(w.claimedPensionSavings, 0);
    });
  });

  group('빠진 공제 진단 — 실제 한 쌍(간소화 × 원천)', () {
    test('이 사용자는 누락 공제 없음(이미 환급 중·문턱/한도 충족)', () {
      final g = parseSimplifiedText(File('test/fixtures/ganso_sample.txt').readAsStringSync());
      final w = parseWithholdingText(File('test/fixtures/wonchun_sample.txt').readAsStringSync());
      final missed = diagnoseMissed(g, w);
      // 의료비 148,400 < 총급여 3%(998,854) → 0, 보장성 이미 100만 한도 신고 → 누락 없음
      expect(missed, isEmpty, reason: missed.map((m) => m.category).join(','));
    });
  });

  group('빠진 공제 진단 — 합성(값 변형)', () {
    test('의료비 문턱 초과 + 미신고 → 누락 검출', () {
      const g = GansoDeductions(medical: 5000000, medicalReimbursed: 0);
      const w = WithholdingReceipt(grossSalary: 30000000, claimedMedical: 0);
      final missed = diagnoseMissed(g, w);
      final med = missed.firstWhere((m) => m.category == '의료비');
      // 5,000,000 − 3%(900,000) = 4,100,000
      expect(med.gap, 4100000);
      expect(med.estimatedRefund, (4100000 * 0.15).round());
    });

    test('보장성 한도 100만 적용 + 미신고 → 누락 100만', () {
      const g = GansoDeductions(lifeInsurance: 3000000);
      const w = WithholdingReceipt(grossSalary: 40000000, claimedLifeInsurance: 0);
      final missed = diagnoseMissed(g, w);
      final life = missed.firstWhere((m) => m.category == '보장성보험');
      expect(life.available, 1000000);
      expect(life.gap, 1000000);
    });

    test('연금저축 한도 600만 적용', () {
      const g = GansoDeductions(pensionSavings: 9000000);
      const w = WithholdingReceipt(grossSalary: 50000000, claimedPensionSavings: 0);
      final missed = diagnoseMissed(g, w);
      final p = missed.firstWhere((m) => m.category == '연금저축');
      expect(p.available, 6000000);
    });

    test('이미 신고된 만큼은 누락 아님', () {
      const g = GansoDeductions(education: 1000000);
      const w = WithholdingReceipt(grossSalary: 40000000, claimedEducation: 1000000);
      final missed = diagnoseMissed(g, w);
      expect(missed.where((m) => m.category == '교육비'), isEmpty);
    });
  });
}
