import '../tax_engine/combined_tax.dart';
import 'withholding_parser.dart';
import 'freelancer_income_parser.dart';

/// N잡러 합산 종합소득세 가상 신고서.
class CombinedReport {
  final List<Map<String, dynamic>> items;
  final double finalAmount; // 환급(+)/추가납부(−이 아니라 부호는 엔진 기준)
  final bool isRefund;
  const CombinedReport({required this.items, required this.finalAmount, required this.isRefund});
}

/// 근로 원천(WithholdingReceipt) + 사업소득(FreelancerReceipt)을 합산해
/// 종합소득세를 계산한다. 사업 PDF엔 업종코드가 없으므로, 이미 경비가 적용된
/// 소득금액을 occupationCode:''(경비율 0)로 넘겨 그대로 사업소득금액으로 쓴다.
CombinedReport buildCombinedReport(WithholdingReceipt labor, FreelancerReceipt biz,
    {int allowanceCount = 0}) {
  final r = CombinedTaxCalculator.calculateCombinedTax(
    grossIncome: labor.grossSalary.toDouble(),
    accumulatedFreelancerIncome: biz.incomeAmount.toDouble(), // 소득금액(경비 적용분)
    inputMonths: 12,
    occupationCode: '', // 경비율 0 → 위 소득금액을 그대로 사업소득금액으로
    creditCard: 0,
    debitCardAndCash: 0,
    traditionalMarket: 0,
    publicTransport: 0,
    cultureExpense: 0,
    allowanceCount: allowanceCount,
    decidedTax: labor.decidedTax.toDouble(), // 근로 기납부(결정세액)
    monthlyRent: 0,
  );

  final items = <Map<String, dynamic>>[
    {'title': '근로소득금액', 'amount': r.laborIncomeAmount, 'isHeader': true},
    {'title': '(+) 사업소득금액', 'amount': r.estimatedFreelancerBusinessIncome},
    {'title': '(=) 종합소득금액', 'amount': r.totalGlobalIncome, 'isHeader': true},
    {'title': '(=) 과세표준', 'amount': r.taxBase, 'isHeader': true, 'highlight': true},
    {'title': '(×) 산출세액 (지방세 포함)', 'amount': r.annualIncomeTax + r.annualLocalTax},
    {'title': '(-) 기납부세액 합계', 'amount': r.annualEstimatedTotalWithholding},
  ];

  return CombinedReport(
    items: items,
    finalAmount: r.expectedRefundOrPayment,
    isRefund: r.expectedRefundOrPayment >= 0,
  );
}
