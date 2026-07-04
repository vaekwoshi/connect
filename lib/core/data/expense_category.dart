import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const ExpenseCategory({required this.id, required this.label, required this.icon, required this.color});
}

const kExpenseCategories = [
  ExpenseCategory(id: '음식/배달', label: '음식/배달', icon: Icons.restaurant_outlined, color: Color(0xFFD69A3A)),
  ExpenseCategory(id: '카페', label: '카페', icon: Icons.local_cafe_outlined, color: Color(0xFFC4884A)),
  ExpenseCategory(id: '편의점', label: '편의점', icon: Icons.store_outlined, color: Color(0xFFD4A853)),
  ExpenseCategory(id: '마트', label: '마트', icon: Icons.shopping_cart_outlined, color: Color(0xFFB87333)),
  ExpenseCategory(id: '온라인쇼핑', label: '온라인쇼핑', icon: Icons.shopping_bag_outlined, color: Color(0xFF7E6EBD)),
  ExpenseCategory(id: '교통', label: '교통', icon: Icons.directions_bus_outlined, color: Color(0xFF5B84B1)),
  ExpenseCategory(id: '주유', label: '주유', icon: Icons.local_gas_station_outlined, color: Color(0xFF4A6FA5)),
  ExpenseCategory(id: '의료/건강', label: '의료/건강', icon: Icons.medical_services_outlined, color: Color(0xFF2FA37A)),
  ExpenseCategory(id: '의류/미용', label: '의류/미용', icon: Icons.checkroom_outlined, color: Color(0xFFB06B8A)),
  ExpenseCategory(id: '교육', label: '교육', icon: Icons.school_outlined, color: Color(0xFF1F5AE0)),
  ExpenseCategory(id: '통신', label: '통신', icon: Icons.smartphone_outlined, color: Color(0xFF6B95B5)),
  ExpenseCategory(id: '주거/관리비', label: '주거/관리비', icon: Icons.home_outlined, color: Color(0xFF5B8C75)),
  ExpenseCategory(id: '보험/금융', label: '보험/금융', icon: Icons.account_balance_outlined, color: Color(0xFF4A7A62)),
  ExpenseCategory(id: '기타', label: '기타', icon: Icons.more_horiz_rounded, color: Color(0xFF8E8B85)),
];

const kPaymentMethods = ['신용카드', '체크+현금', '기타'];

ExpenseCategory expenseCategoryById(String id) =>
    kExpenseCategories.firstWhere((c) => c.id == id, orElse: () => kExpenseCategories.last);
