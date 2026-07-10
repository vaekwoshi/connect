class QuickEntryPreset {
  final int id;
  final String name;
  final int amount;
  final String category;
  final String paymentMethod;
  final bool isBusiness;
  final int sortOrder;

  const QuickEntryPreset({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    this.isBusiness = false,
    this.sortOrder = 0,
  });
}
