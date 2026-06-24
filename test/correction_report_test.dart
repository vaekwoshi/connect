import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/parsing/simplified_data_parser.dart';
import 'package:secul/core/parsing/withholding_parser.dart';
import 'package:secul/core/parsing/correction_report.dart';

void main() {
  group('경정청구 추가환급 산출 — 실제 한 쌍', () {
    test('김경미 쌍 → 추가환급 0 (문턱/한도 충족, 누락 없음)', () {
      final g = parseSimplifiedText(File('test/fixtures/ganso_sample.txt').readAsStringSync());
      final w = parseWithholdingText(File('test/fixtures/wonchun_sample.txt').readAsStringSync());
      final r = buildCorrectionReport(g, w);
      expect(r.additionalRefund, 0);
      expect(r.lines, isEmpty);
      expect(r.hasMissed, false);
    });
  });

  group('경정청구 추가환급 산출 — 합성', () {
    test('기부금+보장성 미신고 → 추가환급 = 두 세액공제 합', () {
      const g = GansoDeductions(donation: 1000000, lifeInsurance: 2000000);
      const w = WithholdingReceipt(grossSalary: 40000000, decidedTax: 5000000);
      final r = buildCorrectionReport(g, w);
      // 기부금 1,000,000×15%=150,000 + 보장성 min(2,000,000,1M)×12%=120,000
      expect(r.additionalRefund, 270000);
      expect(r.lines.length, 2);
      expect(r.lines.firstWhere((l) => l.category == '기부금').missedCredit, 150000);
      expect(r.lines.firstWhere((l) => l.category == '보장성보험').missedCredit, 120000);
    });

    test('추가환급은 결정세액을 넘지 못함(cap)', () {
      const g = GansoDeductions(pensionSavings: 6000000);
      const w = WithholdingReceipt(grossSalary: 40000000, decidedTax: 100000);
      final r = buildCorrectionReport(g, w);
      // 연금저축 600만×15%=900,000 이지만 결정세액 100,000 한도
      expect(r.additionalRefund, 100000);
    });

    test('난임시술비는 30% 고율로 분리 계산', () {
      // 총급여 3천만(문턱 90만), 난임 500만 → 초과 410만 전액 30% = 123만
      const g = GansoDeductions(medical: 5000000, medicalInfertility: 5000000);
      const w = WithholdingReceipt(grossSalary: 30000000, decidedTax: 5000000);
      final med = buildCorrectionReport(g, w).lines.firstWhere((l) => l.category == '의료비');
      expect(med.missedCredit, 1230000);
    });

    test('난임 없이 일반 의료비는 15%', () {
      const g = GansoDeductions(medical: 5000000, medicalInfertility: 0);
      const w = WithholdingReceipt(grossSalary: 30000000, decidedTax: 5000000);
      final med = buildCorrectionReport(g, w).lines.firstWhere((l) => l.category == '의료비');
      expect(med.missedCredit, 615000);
    });

    test('결정세액 0이면 환급 0', () {
      const g = GansoDeductions(donation: 1000000);
      const w = WithholdingReceipt(grossSalary: 40000000, decidedTax: 0);
      expect(buildCorrectionReport(g, w).additionalRefund, 0);
    });

    test('이미 신고한 만큼은 추가 아님', () {
      const g = GansoDeductions(lifeInsurance: 2000000);
      const w = WithholdingReceipt(grossSalary: 40000000, decidedTax: 5000000, claimedLifeInsurance: 1000000);
      // 보장성 이미 한도(100만) 신고 → 추가 0
      expect(buildCorrectionReport(g, w).additionalRefund, 0);
    });
  });

  // 월세 세액공제 자격 게이트 (P1-A)
  group('월세 자격 게이트', () {
    const g = GansoDeductions(rent: 6000000);

    test('소득 요건 충족(연봉 3,600만) 무주택 → 월세 환급 발생', () {
      const w = WithholdingReceipt(grossSalary: 36000000, decidedTax: 5000000);
      final lines = buildCorrectionReport(g, w).lines;
      expect(lines.any((l) => l.category == '월세액'), isTrue);
    });

    test('총급여 8천 초과(연봉 1억) → 자격 없음, 월세 줄 제외', () {
      const w = WithholdingReceipt(grossSalary: 100000000, decidedTax: 10000000);
      final lines = buildCorrectionReport(g, w).lines;
      expect(lines.any((l) => l.category == '월세액'), isFalse);
    });

    test('무주택 아님(isHomeless=false) → 월세 줄 제외', () {
      const w = WithholdingReceipt(grossSalary: 36000000, decidedTax: 5000000);
      final lines = buildCorrectionReport(g, w, isHomeless: false).lines;
      expect(lines.any((l) => l.category == '월세액'), isFalse);
    });
  });
}
