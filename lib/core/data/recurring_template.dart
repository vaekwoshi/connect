class RecurringTemplate {
  final int id;
  final String name;
  final int amountHint;    // 예상 금액 (0이면 미정)
  final String category;   // 지출 카테고리
  final String paymentMethod;
  final int dayOfMonth;    // 보통 빠져나가는 날 (1~31)
  final int sortOrder;

  const RecurringTemplate({
    required this.id,
    required this.name,
    required this.amountHint,
    required this.category,
    required this.paymentMethod,
    required this.dayOfMonth,
    this.sortOrder = 0,
  });

  RecurringTemplate copyWith({
    int? id,
    String? name,
    int? amountHint,
    String? category,
    String? paymentMethod,
    int? dayOfMonth,
    int? sortOrder,
  }) {
    return RecurringTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      amountHint: amountHint ?? this.amountHint,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
