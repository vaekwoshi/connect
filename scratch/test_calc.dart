import '../lib/core/data/occupation_data.dart';
import '../lib/core/tax_engine/freelancer_tax.dart';

void main() {
  print('=== 프리랜서 계산 엔진 테스트 시작 ===');

  // 시나리오 1: 1인미디어창작자 (940909)
  // 누적수입: 3,000만원, 개월수: 6개월, 부양가족: 0명
  // 예상 연소득: 6,000만원
  // 연 추정 단순경비: 4,000만 * 64.1% + 2,000만 * 49.7% = 2,564만 + 994만 = 3,558만원
  // 추정 소득금액: 6,000만 - 3,558만 = 2,442만원
  // 소득공제(본인): 150만원
  // 과세표준: 2,292만원
  // 국세 산출세액: 2,292만 * 15% - 126만 = 217.8만원
  // 지방세 산출세액: 217.8만 * 10% = 21.78만원
  // 연간 추정 총결정세액: 217.8만 + 21.78만 = 2,395,800원 (각각 10원 단위 절사하여 합산)
  // 연간 추정 기납부 3.3% 세액: 6,000만 * 3.3% = 198만원
  // 차감 예상액: 198만 - 2,395,800원 = -415,800원 (추가 납부)
  // 남은 개월수: 6개월 -> 월 권장 저축액: 415,800원 / 6 = 69,300원
  
  final result1 = FreelancerTaxCalculator.calculateTaxSimulation(
    accumulatedIncome: 30000000,
    inputMonths: 6,
    allowanceCount: 0,
    occupationCode: '940909',
  );

  print('\n[시나리오 1 검증: 1인미디어창작자 (940909)]');
  print('업종명: ${result1.occupationName}');
  print('연환산 추정 수입: ${result1.annualEstimatedIncome.toInt()} 원 (기대값: 60000000)');
  print('추정 필요경비: ${result1.estimatedExpense.toInt()} 원 (기대값: 35580000)');
  print('추정 사업소득금액: ${result1.estimatedBusinessIncome.toInt()} 원 (기대값: 24420000)');
  print('추정 과세표준: ${result1.taxBase.toInt()} 원 (기대값: 22920000)');
  print('연 추정 종합소득세 (국세): ${result1.annualIncomeTax.toInt()} 원 (기대값: 2178000)');
  print('연 추정 지방소득세 (지방세): ${result1.annualLocalTax.toInt()} 원 (기대값: 217800)');
  print('연환산 기납부 3.3% 세액: ${result1.annualEstimatedTotalWithholding.toInt()} 원 (기대값: 1980000)');
  print('최종 예상 결과: ${result1.expectedRefundOrPayment.toInt()} 원 (기대값: -415800)');
  print('월 세금 비축 저축액: ${result1.monthlyReserve.toInt()} 원 (기대값: 69300)');
  print('넛지 메시지: ${result1.reserveNudgeMessage}');

  assert(result1.annualEstimatedIncome == 60000000.0);
  assert(result1.estimatedExpense == 35580000.0);
  assert(result1.estimatedBusinessIncome == 24420000.0);
  assert(result1.taxBase == 22920000.0);
  assert(result1.annualIncomeTax == 2178000.0);
  assert(result1.annualLocalTax == 217800.0);
  assert(result1.expectedRefundOrPayment == -415800.0);
  assert(result1.monthlyReserve == 69300.0);
  print('=> 시나리오 1 검증 통과!');


  // 시나리오 2: 기타자영업 (940918)
  // 누적수입: 1,000만원, 개월수: 3개월, 부양가족: 1명 (본인 포함 2명 공제: 300만원)
  // 예상 연소득: 4,000만원
  // 연 추정 단순경비: 4,000만 * 79.4% = 3,176만원
  // 추정 소득금액: 4,000만 - 3,176만 = 824만원
  // 소득공제(본인+1인): 300만원
  // 과세표준: 524만원
  // 국세 산출세액: 524만 * 6% = 314,400원
  // 지방세 산출세액: 31,440원 (314,400원 * 10% 원화 절사)
  // 연간 추정 총결정세액: 314,400 + 31,440 = 345,840원
  // 연간 추정 기납부 3.3% 세액: 4,000만 * 3.3% = 132만원 (국세 120만, 지방세 12만)
  // 차감 예상액: 132만 - 345,840원 = 974,160원 (환급)
  
  final result2 = FreelancerTaxCalculator.calculateTaxSimulation(
    accumulatedIncome: 10000000,
    inputMonths: 3,
    allowanceCount: 1,
    occupationCode: '940918',
  );

  print('\n[시나리오 2 검증: 기타자영업 (940918)]');
  print('업종명: ${result2.occupationName}');
  print('연환산 추정 수입: ${result2.annualEstimatedIncome.toInt()} 원 (기대값: 40000000)');
  print('추정 필요경비: ${result2.estimatedExpense.toInt()} 원 (기대값: 31760000)');
  print('추정 사업소득금액: ${result2.estimatedBusinessIncome.toInt()} 원 (기대값: 8240000)');
  print('추정 과세표준: ${result2.taxBase.toInt()} 원 (기대값: 5240000)');
  print('연 추정 종합소득세 (국세): ${result2.annualIncomeTax.toInt()} 원 (기대값: 314400)');
  print('연 추정 지방소득세 (지방세): ${result2.annualLocalTax.toInt()} 원 (기대값: 31440)');
  print('최종 예상 결과: ${result2.expectedRefundOrPayment.toInt()} 원 (기대값: 974160)');
  print('넛지 메시지: ${result2.reserveNudgeMessage}');

  assert(result2.annualEstimatedIncome == 40000000.0);
  assert(result2.estimatedExpense == 31760000.0);
  assert(result2.estimatedBusinessIncome == 8240000.0);
  assert(result2.taxBase == 5240000.0);
  assert(result2.annualIncomeTax == 314400.0);
  assert(result2.annualLocalTax == 31440.0);
  assert(result2.expectedRefundOrPayment == 974160.0);
  print('=> 시나리오 2 검증 통과!');

  print('\n=== 모든 검증 완료: 100% 성공! ===');
}
