import 'dart:convert';
import 'package:flutter/services.dart';
import '../data/product_card.dart';
import '../data/expense_item.dart';

class ScoredCard {
  final ProductCard card;
  final double netMonthlyBenefit;
  const ScoredCard({required this.card, required this.netMonthlyBenefit});
}

class ProductService {
  static List<ProductCard>? _cache;

  static Future<List<ProductCard>> loadCards() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/products.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _cache = (data['cards'] as List)
        .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  static List<ScoredCard> score(
    List<ProductCard> cards,
    Map<String, int> monthlySpending,
  ) {
    final scored = cards.map((card) {
      double benefit = 0;
      for (final entry in card.benefits.entries) {
        final spend = monthlySpending[entry.key] ?? 0;
        final b = entry.value;
        final raw = spend * b.rate * b.pointValue;
        benefit += raw.clamp(0, b.capMonthly.toDouble());
      }
      final capped = benefit.clamp(0, card.benefitCapMonthly.toDouble());
      final net = capped - card.annualFee / 12;
      return ScoredCard(card: card, netMonthlyBenefit: net);
    }).toList();

    scored.sort((a, b) => b.netMonthlyBenefit.compareTo(a.netMonthlyBenefit));
    return scored;
  }

  // Returns average monthly spend per category over the last 6 months.
  static Map<String, int> buildSpendingProfile(List<ExpenseItem> expenses) {
    final cutoff = DateTime.now().subtract(const Duration(days: 180));
    final recent = expenses.where((e) => e.date.isAfter(cutoff)).toList();

    final totals = <String, int>{};
    for (final e in recent) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    return totals.map((k, v) => MapEntry(k, (v / 6).round()));
  }

  // Synthetic profile when no spending data — built from questionnaire answers.
  static Map<String, int> profileFromQuestionnaire({
    required String channel, // 'online' | 'offline' | 'mixed'
    required String lifestyle, // 'commuter' | 'driver' | 'homebody'
    int maxAnnualFee = 999999,
  }) {
    final profile = <String, int>{};

    switch (channel) {
      case 'online':
        profile['온라인쇼핑'] = 300000;
        profile['음식/배달'] = 150000;
        profile['카페'] = 80000;
        profile['통신'] = 80000;
      case 'offline':
        profile['마트'] = 250000;
        profile['음식/배달'] = 200000;
        profile['편의점'] = 80000;
        profile['의류/미용'] = 100000;
      default: // mixed
        profile['온라인쇼핑'] = 150000;
        profile['마트'] = 150000;
        profile['음식/배달'] = 150000;
        profile['편의점'] = 60000;
        profile['카페'] = 60000;
    }

    switch (lifestyle) {
      case 'commuter':
        profile['교통'] = 80000;
        profile['카페'] = (profile['카페'] ?? 0) + 40000;
      case 'driver':
        profile['주유'] = 150000;
        profile['교통'] = 20000;
      default:
        profile['주거/관리비'] = 100000;
        profile['의료/건강'] = 50000;
    }

    return profile;
  }
}
