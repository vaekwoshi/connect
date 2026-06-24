import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/data/db_helper.dart';
import '../../core/data/expense_item.dart';

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final _numberFormat = NumberFormat('#,###');

  String _category = '신용카드';
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year, 1, 1),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: Theme.of(ctx).textTheme.bodyLarge!.color!,
            onPrimary: Theme.of(ctx).scaffoldBackgroundColor,
            surface: Theme.of(ctx).cardColor,
            onSurface: Theme.of(ctx).textTheme.bodyLarge!.color!,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amountStr = _amountController.text.replaceAll(',', '');
    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('금액을 입력해주세요.'),
        backgroundColor: Theme.of(context).cardColor,
      ));
      return;
    }

    setState(() => _isSaving = true);

    final memo = _memoController.text.trim();
    final item = ExpenseItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: _date,
      amount: amount,
      content: memo.isEmpty ? _category : memo,
      category: _category,
    );

    await dbService.insertExpense(item);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;

    final dateLabel = _date.year == DateTime.now().year
        ? '${_date.month}월 ${_date.day}일'
        : '${_date.year}.${_date.month}.${_date.day}';
    final isToday = _date.year == DateTime.now().year &&
        _date.month == DateTime.now().month &&
        _date.day == DateTime.now().day;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('지출 추가', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 금액 입력
              Text('얼마를 쓰셨나요?', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: subColor, fontSize: 32, fontWeight: FontWeight.w800),
                    border: InputBorder.none,
                    suffixText: '원',
                    suffixStyle: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  onChanged: (value) {
                    final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
                    final formatted = numeric.isEmpty ? '' : _numberFormat.format(int.parse(numeric));
                    _amountController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  },
                ),
              ),

              const SizedBox(height: 28),

              // 결제 수단
              Text('결제 수단', style: TextStyle(color: subColor, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _categoryButton('신용카드', Icons.credit_card_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _categoryButton('체크+현금', Icons.account_balance_wallet_rounded)),
                ],
              ),

              const SizedBox(height: 28),

              // 날짜
              Text('날짜', style: TextStyle(color: subColor, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: textColor, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        isToday ? '오늘 ($dateLabel)' : dateLabel,
                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, color: subColor),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 메모 (선택)
              Text('메모 (선택)', style: TextStyle(color: subColor, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                child: TextField(
                  controller: _memoController,
                  style: TextStyle(color: textColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '예: 편의점, 외식, 쇼핑...',
                    hintStyle: TextStyle(color: subColor, fontSize: 15),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 추가하기 버튼
              GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _isSaving ? subColor : textColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _isSaving ? '저장 중...' : '추가하기',
                    style: TextStyle(color: bgColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryButton(String label, IconData icon) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final cardColor = Theme.of(context).cardColor;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isSelected = _category == label;

    return GestureDetector(
      onTap: () => setState(() => _category = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? textColor : cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? bgColor : textColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? bgColor : textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
