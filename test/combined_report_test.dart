import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/parsing/withholding_parser.dart';
import 'package:secul/core/parsing/freelancer_income_parser.dart';
import 'package:secul/core/parsing/combined_report.dart';

void main() {
  group('N잡러 합산 신고서', () {
    test('종합소득금액 = 근로소득금액 + 사업소득금액 (불변식)', () {
      const labor = WithholdingReceipt(grossSalary: 40000000, decidedTax: 1500000);
      const biz = FreelancerReceipt(grossIncome: 25000000, incomeAmount: 20000000);
      final r = buildCombinedReport(labor, biz);
      final laborAmt = r.items[0]['amount'] as double;
      final bizAmt = r.items[1]['amount'] as double;
      final total = r.items[2]['amount'] as double;
      expect(total, laborAmt + bizAmt);
      // 경비율 0 → 사업소득금액 = 넘긴 소득금액
      expect(bizAmt, 20000000.0);
    });

    test('항목 구조 6줄 + 환급/납부 부호', () {
      const labor = WithholdingReceipt(grossSalary: 50000000, decidedTax: 3000000);
      const biz = FreelancerReceipt(grossIncome: 30000000, incomeAmount: 18000000);
      final r = buildCombinedReport(labor, biz);
      expect(r.items.length, 6);
      expect(r.items.last['title'], '(-) 기납부세액 합계');
      // 과세표준 = 종합소득금액 − 인적공제(150만) 이상이어야
      final taxBase = r.items[3]['amount'] as double;
      final total = r.items[2]['amount'] as double;
      expect(taxBase, lessThanOrEqualTo(total));
      expect(taxBase, greaterThan(0));
    });

    test('합산하면 과세표준이 근로 단독보다 커진다', () {
      const labor = WithholdingReceipt(grossSalary: 40000000, decidedTax: 1500000);
      const noBiz = FreelancerReceipt();
      const withBiz = FreelancerReceipt(grossIncome: 20000000, incomeAmount: 15000000);
      final base0 = buildCombinedReport(labor, noBiz).items[3]['amount'] as double;
      final base1 = buildCombinedReport(labor, withBiz).items[3]['amount'] as double;
      expect(base1, greaterThan(base0));
    });
  });
}
