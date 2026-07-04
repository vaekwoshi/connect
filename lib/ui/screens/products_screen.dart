import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProductsScreen extends StatelessWidget {
  final String userType;
  const ProductsScreen({super.key, required this.userType});

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('상품'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 12),
              Text('금융상품', style: AppTheme.serif(28, ink, spacing: -0.5, height: 1.2)),
              const SizedBox(height: 10),
              Text('내 소비 패턴에 맞는 카드·보험·금융상품을 추천해 드릴 예정이에요.',
                  style: AppTheme.sans(14, sub, height: 1.55)),
              const Spacer(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 40, color: tert),
                    const SizedBox(height: 16),
                    Text('서비스 준비 중', style: AppTheme.sans(16, ink, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('곧 만나볼 수 있어요', style: AppTheme.sans(13, tert)),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
