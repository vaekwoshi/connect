import 'package:flutter/material.dart';
import '../components/amount_field.dart';

class EmployeeInputScreen extends StatefulWidget {
  final String initialSalary;
  final String initialGrossIncome;

  const EmployeeInputScreen({
    super.key,
    this.initialSalary = '',
    this.initialGrossIncome = '',
  });

  @override
  State<EmployeeInputScreen> createState() => _EmployeeInputScreenState();
}

class _EmployeeInputScreenState extends State<EmployeeInputScreen> {
  late TextEditingController _salaryController;
  late TextEditingController _grossIncomeController;

  @override
  void initState() {
    super.initState();
    _salaryController = TextEditingController(text: widget.initialSalary);
    _grossIncomeController = TextEditingController(text: widget.initialGrossIncome);
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _grossIncomeController.dispose();
    super.dispose();
  }

  Widget _buildSalaryField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AmountField(controller: controller, expand: true),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).textTheme.bodyLarge!.color!),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('나의 재무 목표 및 소비', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '내 월급·연봉을\n관리해 주세요.',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.w800, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  _buildSalaryField('예상 연봉 (세전, 연간)', _grossIncomeController, '예: 36,000,000'),
                  const SizedBox(height: 8),
                  Text(
                    '실수령액·신용카드 공제 문턱·세금 계산의 기준이 돼요.',
                    style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  _buildSalaryField('당월 급여 (세전)', _salaryController, '예: 3,000,000'),
                  const SizedBox(height: 8),
                  Text(
                    '이번 달 실제 수령액. 달력 기록과 함께 관리돼요.',
                    style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context, {
                    'salary': _salaryController.text,
                    'grossIncome': _grossIncomeController.text,
                  });
                },
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Theme.of(context).textTheme.bodyLarge!.color!, borderRadius: BorderRadius.circular(16)),
                  child: Text('저장하기', style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
