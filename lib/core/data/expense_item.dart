class ExpenseItem {
  final String id;
  final DateTime date;
  final DateTime? endDate; // null = 단일 날짜, non-null = 기간 지출
  final int amount;
  final String content;
  final String category;

  ExpenseItem({
    required this.id,
    required this.date,
    this.endDate,
    required this.amount,
    required this.content,
    required this.category,
  });

  ExpenseItem copyWith({
    String? id,
    DateTime? date,
    DateTime? endDate,
    int? amount,
    String? content,
    String? category,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      amount: amount ?? this.amount,
      content: content ?? this.content,
      category: category ?? this.category,
    );
  }
}
