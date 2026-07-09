class RecurringTemplate {
  final int id;
  final String name;
  final int amountHint;    // 예상 금액 (0이면 미정)
  final String category;   // 지출 카테고리
  final String paymentMethod;
  final int dayOfMonth;    // 보통 빠져나가는 날 (1~31)
  final int sortOrder;
  /// 사업경비 기본값 — 이 템플릿에서 확정되는 지출에 매번 다시 토글하지 않도록
  /// 기본으로 물려준다(사용자가 확정 화면에서 개별 수정 가능).
  final bool isBusiness;

  const RecurringTemplate({
    required this.id,
    required this.name,
    required this.amountHint,
    required this.category,
    required this.paymentMethod,
    required this.dayOfMonth,
    this.sortOrder = 0,
    this.isBusiness = false,
  });

  RecurringTemplate copyWith({
    int? id,
    String? name,
    int? amountHint,
    String? category,
    String? paymentMethod,
    int? dayOfMonth,
    int? sortOrder,
    bool? isBusiness,
  }) {
    return RecurringTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      amountHint: amountHint ?? this.amountHint,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      sortOrder: sortOrder ?? this.sortOrder,
      isBusiness: isBusiness ?? this.isBusiness,
    );
  }
}
