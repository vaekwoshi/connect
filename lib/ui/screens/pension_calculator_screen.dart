import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';

import '../theme/app_theme.dart';
import '../../core/data/db_helper.dart';
import '../../core/tax_engine/employee_tax.dart';

/// 연금저축·IRP 절세 계산기
/// 엔진: EmployeeTaxCalculator.calculatePensionAccountTaxCredit (소법 §59의3)
/// - 연금저축 공제대상 한도 600만, (연금저축+퇴직연금) 합산 900만
/// - 공제율 15% (총급여 5,500만 이하) / 12% (초과)
class PensionCalculatorScreen extends StatefulWidget {
  const PensionCalculatorScreen({super.key});

  @override
  State<PensionCalculatorScreen> createState() => _PensionCalculatorScreenState();
}

class _PensionCalculatorScreenState extends State<PensionCalculatorScreen> {
  final TextEditingController _grossIncomeController = TextEditingController();
  final TextEditingController _savingsController = TextEditingController();
  final TextEditingController _irpController = TextEditingController();
  final _numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await dbService.getProfile();
    if (profile != null && mounted) {
      final gross = (profile['gross_income'] as num?)?.toDouble() ?? 0.0;
      if (gross > 0) {
        setState(() {
          _grossIncomeController.text = _numberFormat.format(gross.toInt());
        });
      }
    }
  }

  @override
  void dispose() {
    _grossIncomeController.dispose();
    _savingsController.dispose();
    _irpController.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0.0;

  String _toManwon(double won) {
    if (won <= 0) return '0원';
    final man = (won / 10000).round();
    return '${_numberFormat.format(man)}만원';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;

    final grossIncome = _parse(_grossIncomeController);
    final savings = _parse(_savingsController);
    final irp = _parse(_irpController);

    // 공제대상 산정 (엔진과 동일 규칙)
    final eligibleSavings = savings > 6000000.0 ? 6000000.0 : savings;
    double eligibleTotal = eligibleSavings + irp;
    if (eligibleTotal > 9000000.0) eligibleTotal = 9000000.0;
    final rate = grossIncome <= 55000000.0 ? 0.15 : 0.12;

    final credit = EmployeeTaxCalculator.calculatePensionAccountTaxCredit(
      pensionSavingsPayment: savings,
      retirementPensionPayment: irp,
      grossIncome: grossIncome,
    );

    final hasInput = savings > 0 || irp > 0;
    // 추가 납입 여력 (합산 900만 한도까지)
    final remainingRoom = (9000000.0 - eligibleTotal).clamp(0.0, 9000000.0);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('연금저축·IRP 절세 계산기',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('연금계좌에 넣은 만큼\n세금을 돌려받아요',
                style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 8),
            Text('연금저축과 퇴직연금(IRP) 납입액으로 받을 수 있는 세액공제를 계산합니다.',
                style: TextStyle(color: subColor, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),

            // 입력 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getCardDecoration(context, borderRadius: 20),
              child: Column(
                children: [
                  _buildInputField('총급여(연봉)', _grossIncomeController,
                      hint: '공제율 판정에 사용돼요'),
                  const SizedBox(height: 20),
                  _buildInputField('연금저축 납입액', _savingsController,
                      hint: '연 600만원까지 공제'),
                  const SizedBox(height: 20),
                  _buildInputField('퇴직연금(IRP/DC) 납입액', _irpController,
                      hint: '연금저축과 합산 900만원까지'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결과 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.getAccentCardDecoration(context, borderRadius: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.savings_rounded, color: primary, size: 20),
                    const SizedBox(width: 8),
                    Text('예상 절세액 (세액공제)',
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  Text(hasInput ? _toManwon(credit) : '0원',
                      style: TextStyle(color: primary, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (hasInput) ...[
                    _resultRow('적용 공제율', '${(rate * 100).toStringAsFixed(0)}%', subColor, textColor),
                    const SizedBox(height: 8),
                    _resultRow('공제대상 금액', _toManwon(eligibleTotal), subColor, textColor),
                    if (savings > 6000000.0) ...[
                      const SizedBox(height: 8),
                      _resultRow('연금저축 한도 초과', '+${_toManwon(savings - 6000000.0)}는 공제 제외',
                          subColor, Colors.orange),
                    ],
                    if (remainingRoom > 0) ...[
                      const SizedBox(height: 8),
                      _resultRow('추가 납입 여력', '${_toManwon(remainingRoom)} 더 가능', subColor, primary),
                    ],
                  ] else
                    Text('연금저축 또는 IRP 납입액을 입력해보세요.',
                        style: TextStyle(color: subColor, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 안내 박스
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: subColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline_rounded, color: subColor, size: 16),
                    const SizedBox(width: 6),
                    Text('알아두기', style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '• 총급여 5,500만원 이하는 공제율 15%, 초과는 12%입니다.\n'
                    '• 연금저축은 연 600만원, IRP 포함 합산 900만원까지 공제 대상입니다.\n'
                    '• 세액공제는 결정세액에서 직접 차감되어 환급으로 돌아옵니다.',
                    style: TextStyle(color: subColor, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {String? hint}) {
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: subColor, fontSize: 14)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(color: subColor.withOpacity(0.7), fontSize: 11)),
        ],
        const SizedBox(height: 4),
        AmountField(controller: controller, expand: true, onChanged: (_) => setState(() {})),
      ],
    );
  }
}
