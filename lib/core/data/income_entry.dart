class IncomeEntry {
  final String id;
  final DateTime date;
  final DateTime? endDate; // null = 단일 날짜, non-null = 기간 수입
  final int amount;
  final String memo;
  final String incomeType; // '급여', '프리랜서', '부수입', '기타'

  IncomeEntry({
    required this.id,
    required this.date,
    this.endDate,
    required this.amount,
    required this.memo,
    required this.incomeType,
  });

  IncomeEntry copyWith({
    String? id,
    DateTime? date,
    DateTime? endDate,
    int? amount,
    String? memo,
    String? incomeType,
  }) {
    return IncomeEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      incomeType: incomeType ?? this.incomeType,
    );
  }
}
