import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/parsing/freelancer_income_parser.dart';

void main() {
  group('프리랜서 사업소득 파서 — 구조 합성 골든', () {
    // ※ 실파일 미확보 — 앵커는 [별지23(3)] 구조 추정. 구조·로직 검증용.
    late FreelancerReceipt r;
    setUpAll(() {
      r = parseFreelancerText(File('test/fixtures/freelancer_sample.txt').readAsStringSync());
    });

    test('수입·소득금액·세액 추출', () {
      expect(r.grossIncome, 30000000, reason: '합계(124) 총수입');
      expect(r.incomeAmount, 12000000, reason: '소득금액(수입−경비)');
      expect(r.decidedTax, 600000);
      expect(r.finalSettlement, -300000, reason: '차감납부(음수=환급)');
    });

    test('기납부(3.3%)는 결정−차감으로 도출', () {
      expect(r.withheldTax, 900000); // 결정 60만 − 차감 -30만 = 90만 (= 3천만×3%)
      expect(r.isRefund, true);
      expect(r.settlementAbs, 300000);
    });

    test('종소세 가상 신고서 items 조립', () {
      final items = buildFreelancerReportItems(r);
      expect(items.first['title'], '총수입금액');
      expect(items.first['amount'], 30000000.0);
      expect(items.any((i) => i['title'] == '(-) 기납부세액 (3.3%)' && i['amount'] == 900000.0), true);
    });
  });

  group('프리랜서 파서 — 합성 엣지', () {
    test('추가납부 케이스(차감 양수)', () {
      const text = '''
[별지 제23호서식(3)]
합 계 (124)50,000,000
소득금액20,000,000
결정세액1,500,000
차감 납부할 세액400,000
''';
      final r = parseFreelancerText(text);
      expect(r.grossIncome, 50000000);
      expect(r.finalSettlement, 400000);
      expect(r.isRefund, false);
      expect(r.withheldTax, 1100000); // 150만 − 40만
    });
  });
}
