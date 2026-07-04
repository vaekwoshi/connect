import 'package:flutter/material.dart';

class ProductBenefit {
  final double rate;
  final String type; // 'cashback' | 'points'
  final int capMonthly;
  final double pointValue;

  const ProductBenefit({
    required this.rate,
    required this.type,
    required this.capMonthly,
    this.pointValue = 1.0,
  });

  factory ProductBenefit.fromJson(Map<String, dynamic> j) => ProductBenefit(
        rate: (j['rate'] as num).toDouble(),
        type: j['type'] as String,
        capMonthly: j['cap_monthly'] as int,
        pointValue: (j['point_value'] as num?)?.toDouble() ?? 1.0,
      );
}

class ProductCard {
  final String id;
  final String name;
  final String company;
  final Color color;
  final String cardType;
  final int annualFee;
  final int popularityRank;
  final DateTime addedDate;
  final String summary;
  final int minSpend;
  final int benefitCapMonthly;
  final String applyUrl;
  final Map<String, ProductBenefit> benefits;
  final List<String> specialBenefits;
  final String productType; // '카드' | '보험' | '금융'

  const ProductCard({
    required this.id,
    required this.name,
    required this.company,
    required this.color,
    required this.cardType,
    required this.annualFee,
    required this.popularityRank,
    required this.addedDate,
    required this.summary,
    required this.minSpend,
    required this.benefitCapMonthly,
    required this.applyUrl,
    required this.benefits,
    required this.specialBenefits,
    this.productType = '카드',
  });

  factory ProductCard.fromJson(Map<String, dynamic> j) {
    final colorHex = j['color'] as String;
    final colorValue = int.parse(colorHex.replaceFirst('0x', ''), radix: 16);

    final benefitsJson = j['benefits'] as Map<String, dynamic>;
    final benefits = benefitsJson.map(
      (k, v) => MapEntry(k, ProductBenefit.fromJson(v as Map<String, dynamic>)),
    );

    return ProductCard(
      id: j['id'] as String,
      name: j['name'] as String,
      company: j['company'] as String,
      color: Color(colorValue),
      cardType: j['card_type'] as String,
      annualFee: j['annual_fee'] as int,
      popularityRank: j['popularity_rank'] as int,
      addedDate: DateTime.parse(j['added_date'] as String),
      summary: j['summary'] as String,
      minSpend: j['min_spend'] as int,
      benefitCapMonthly: j['benefit_cap_monthly'] as int,
      applyUrl: j['apply_url'] as String,
      benefits: benefits,
      specialBenefits: List<String>.from(j['special_benefits'] as List),
      productType: j['product_type'] as String? ?? '카드',
    );
  }

  String get topBenefitLabel {
    if (benefits.isEmpty) return '';
    final top = benefits.entries.reduce((a, b) => a.value.rate >= b.value.rate ? a : b);
    final pct = (top.value.rate * 100).toStringAsFixed(top.value.rate % 0.01 == 0 ? 0 : 1);
    return '${top.key} $pct%';
  }
}
