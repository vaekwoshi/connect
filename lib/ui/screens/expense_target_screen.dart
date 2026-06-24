import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../components/amount_field.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/expense_item.dart';
import '../../core/security/notification_helper.dart';

class ExpenseTargetScreen extends StatefulWidget {
  final String userType;
  final double threshold;
  final double monthlyIncome;

  const ExpenseTargetScreen({
    super.key, 
    required this.userType,
    required this.threshold,
    required this.monthlyIncome,
  });

  @override
  State<ExpenseTargetScreen> createState() => _ExpenseTargetScreenState();
}

class _ExpenseTargetScreenState extends State<ExpenseTargetScreen> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  final TextEditingController _debitController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  final _numberFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await dbService.getProfile();
    if (profile != null && mounted) {
      final target = profile['expense_target'] as double? ?? 0.0;
      if (target > 0) {
        _targetController.text = _numberFormat.format(target.toInt());
      }
    }

    final expenses = await dbService.getExpenses();
    if (mounted) {
      int creditTotal = 0;
      int debitTotal = 0;
      int cashTotal = 0;
      for (final exp in expenses) {
        if (exp.category == '신용카드') creditTotal += exp.amount;
        else if (exp.category == '체크카드') debitTotal += exp.amount;
        else if (exp.category == '현금영수증') cashTotal += exp.amount;
      }
      
      setState(() {
        if (creditTotal > 0) _creditController.text = _numberFormat.format(creditTotal);
        if (debitTotal > 0) _debitController.text = _numberFormat.format(debitTotal);
        if (cashTotal > 0) _cashController.text = _numberFormat.format(cashTotal);
      });
    }
  }

  Future<void> _saveData() async {
    final targetAmt = int.tryParse(_targetController.text.replaceAll(',', '')) ?? 0;
    final creditAmt = int.tryParse(_creditController.text.replaceAll(',', '')) ?? 0;
    final debitAmt = int.tryParse(_debitController.text.replaceAll(',', '')) ?? 0;
    final cashAmt = int.tryParse(_cashController.text.replaceAll(',', '')) ?? 0;

    // 프로필에 지출 목표 업데이트
    final profile = await dbService.getProfile() ?? {};
    profile['expense_target'] = targetAmt.toDouble();
    await dbService.saveProfile(profile);

    // 지출 내역 덮어쓰기 로직 (간소화)
    await dbService.insertExpense(ExpenseItem(id: 'monthly_credit', date: DateTime.now(), amount: creditAmt, content: '신용카드 지출', category: '신용카드'));
    await dbService.insertExpense(ExpenseItem(id: 'monthly_debit', date: DateTime.now(), amount: debitAmt, content: '체크카드 지출', category: '체크카드'));
    await dbService.insertExpense(ExpenseItem(id: 'monthly_cash', date: DateTime.now(), amount: cashAmt, content: '현금 지출', category: '현금영수증'));

    final totalSpending = creditAmt + debitAmt + cashAmt;
    if (widget.monthlyIncome > 0 && widget.threshold > 0 && totalSpending >= widget.threshold) {
      notificationHelper.showImmediateNotification(
        id: 1,
        title: '🚨 공제 문턱(25%) 돌파 완료!',
        body: '지금부터는 체크카드나 현금영수증을 쓰셔야 최대 환급을 받습니다!',
      );
    } else if (widget.monthlyIncome > 0) {
      notificationHelper.scheduleNotification(
        id: 2,
        title: '지출을 점검할 시간이에요',
        body: '이번 주 지출 내역을 입력하고 황금비율을 확인하세요!',
        delay: const Duration(days: 7),
      );
    }
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 14)),
        const SizedBox(height: 4),
        AmountField(controller: controller, expand: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F141A),
        elevation: 0,
        title: Text('지출 목표 및 내역 설정', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.bodyLarge!.color!),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이번 달에는\n얼마를 목표로 하실 건가요?', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 24, fontWeight: FontWeight.bold, height: 1.4)),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
              child: _buildInputField('이번 달 지출 목표', _targetController),
            ),
            const SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.credit_card_rounded, color: Theme.of(context).primaryColor, size: 20),
                      SizedBox(width: 8),
                      Text('현재 지출 현황 입력', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildInputField('신용카드 사용액', _creditController),
                  const SizedBox(height: 20),
                  _buildInputField('체크카드 사용액', _debitController),
                  const SizedBox(height: 20),
                  _buildInputField('현금영수증 발행액', _cashController),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  await _saveData();
                  if (mounted) Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('저장하기', style: TextStyle(color: Color(0xFF0F141A), fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
